# frozen_string_literal: true

module YahtzeeBot
  class MessageHandler
    CATEGORY_NAMES = {
      1 => 'Единицы', 2 => 'Двойки', 3 => 'Тройки',
      4 => 'Четвёрки', 5 => 'Пятёрки', 6 => 'Шестёрки',
      7 => 'Три равных', 8 => 'Четыре равных',
      9 => 'Фул-хаус', 10 => 'Малая последовательность',
      11 => 'Большая последовательность', 12 => 'Yahtzee',
      13 => 'Шанс'
    }.freeze

    class << self
      def handle(bot, message, game, persistence)
        text = message.text.to_s.strip
        chat_id = message.chat.id
        user = message.from

        case text
        when '/start'
          send_welcome(bot, chat_id)
        when '/new'
          create_new_game(bot, chat_id, game)
        when '/help'
          send_help(bot, chat_id)
        when '/rules'
          send_rules(bot, chat_id)
        when '/categories'
          send_categories(bot, chat_id)
        when '/stats'
          show_stats(bot, chat_id, user, persistence)
        when '/leaderboard'
          show_leaderboard(bot, chat_id, persistence)
        when '/stop'
          stop_game(bot, chat_id, game, persistence)
        when /^\/join\s+(.+)$/
          join_game(bot, chat_id, game, ::Regexp.last_match(1), user)
        when '/start_game'
          start_game(bot, chat_id, game)
        when '/roll'
          roll_dice(bot, chat_id, game)
        when /^\/reroll(?:\s+(.+))?$/
          reroll_dice(bot, chat_id, game, ::Regexp.last_match(1))
        when /^\/score\s+(\d+)$/
          select_category(bot, chat_id, game, ::Regexp.last_match(1).to_i)
        when '/table'
          show_table(bot, chat_id, game)
        when '/current'
          show_current_state(bot, chat_id, game)
        else
          handle_unknown(bot, chat_id)
        end
      end

      private

      def send_welcome(bot, chat_id)
        text = <<~WELCOME
          Добро пожаловать в Yahtzee!

          Это классическая игра в кости, где нужно набирать комбинации и зарабатывать очки.

          Основные команды:
          /new - Создать новую игру
          /join [имя] - Присоединиться к игре
          /start_game - Начать игру
          /roll - Бросить кубики
          /reroll [1-5] - Перебросить выбранные кубики
          /score [1-13] - Выбрать категорию
          /table - Показать таблицу очков
          /categories - Список всех категорий
          /stats - Ваша статистика
          /leaderboard - Таблица лидеров
          /help - Полная справка
          /rules - Правила игры
        WELCOME

        bot.api.send_message(chat_id: chat_id, text: text)
      end

      def create_new_game(bot, chat_id, game)
        game&.finish if game&.state != :waiting_for_players

        @current_game = Yahtzee::Game.new(chat_id: chat_id)
        bot.api.send_message(
          chat_id: chat_id,
          text: "Новая игра создана!\nИспользуйте /join [имя] чтобы присоединиться.",
          reply_markup: Keyboard.join_keyboard
        )
      end

      def join_game(bot, chat_id, game, name, user)
        unless game
          bot.api.send_message(chat_id: chat_id, text: 'Сначала создайте игру с помощью /new')
          return
        end

        player = game.add_player(name, user.id)
        players_list = game.players.map(&:name).join(', ')

        bot.api.send_message(
          chat_id: chat_id,
          text: "#{player.name} присоединился к игре!\n\nИгроки: #{players_list}",
          reply_markup: game.players.size >= 2 ? Keyboard.start_game_keyboard : nil
        )
      rescue StandardError => e
        bot.api.send_message(chat_id: chat_id, text: "Ошибка: #{e.message}")
      end

      def start_game(bot, chat_id, game)
        unless game
          bot.api.send_message(chat_id: chat_id, text: 'Сначала создайте игру с помощью /new')
          return
        end

        game.start
        current = game.current_player

        bot.api.send_message(
          chat_id: chat_id,
          text: "Игра начинается!\n\nХод игрока: #{current.name}\n" \
                "Используйте /roll чтобы бросить кубики.",
          reply_markup: Keyboard.game_keyboard
        )
      rescue StandardError => e
        bot.api.send_message(chat_id: chat_id, text: "Ошибка: #{e.message}")
      end

      def roll_dice(bot, chat_id, game)
        unless valid_game_state?(bot, chat_id, game)
          return
        end

        dice_values = game.roll_dice
        emojis = game.dice.to_emojis

        text = "#{game.current_player.name} бросает кубики:\n\n" \
               "#{emojis}\n#{dice_values.join(' ')}\n\n"

        if game.dice.can_roll?
          text += "Осталось перебросов: #{game.dice.rolls_left}\n" \
                  "Можете перебросить кубики: /reroll 1 3 5"
        else
          text += "Перебросов не осталось!\n" \
                  "Выберите категорию: /score [1-13]"
        end

        bot.api.send_message(
          chat_id: chat_id,
          text: text,
          reply_markup: Keyboard.roll_keyboard(game.dice.rolls_left)
        )
      rescue StandardError => e
        bot.api.send_message(chat_id: chat_id, text: "Ошибка: #{e.message}")
      end

      def reroll_dice(bot, chat_id, game, positions_str)
        unless valid_game_state?(bot, chat_id, game)
          return
        end

        positions = positions_str.to_s.split.map(&:to_i).select { |p| p.between?(1, 5) }

        if positions.empty?
          bot.api.send_message(
            chat_id: chat_id,
            text: 'Укажите позиции кубиков для переброса (от 1 до 5)'
          )
          return
        end

        dice_values = game.reroll_dice(positions)
        emojis = game.dice.to_emojis

        text = "#{game.current_player.name} перебрасывает кубики #{positions.join(', ')}:\n\n" \
               "#{emojis}\n#{dice_values.join(' ')}\n\n"

        if game.dice.can_roll?
          text += "Осталось перебросов: #{game.dice.rolls_left}"
        else
          text += "Перебросов не осталось!\n" \
                  "Выберите категорию: /score [1-13]"
        end

        bot.api.send_message(
          chat_id: chat_id,
          text: text,
          reply_markup: Keyboard.roll_keyboard(game.dice.rolls_left)
        )
      rescue StandardError => e
        bot.api.send_message(chat_id: chat_id, text: "Ошибка: #{e.message}")
      end

      def select_category(bot, chat_id, game, category)
        unless valid_game_state?(bot, chat_id, game, check_dice: true)
          return
        end

        unless category.between?(1, 13)
          bot.api.send_message(chat_id: chat_id, text: 'Категория должна быть от 1 до 13')
          return
        end

        player_name = game.current_player.name
        points = game.select_category(category, player_name)

        category_name = CATEGORY_NAMES[category]
        text = "#{player_name} выбрал категорию: #{category_name}\n" \
               "Набрано очков: #{points}\n"

        if game.game_over?
          handle_game_over(bot, chat_id, game, text)
        else
          text += "\nСледующий ход: #{game.current_player.name}"
          bot.api.send_message(
            chat_id: chat_id,
            text: text,
            reply_markup: Keyboard.game_keyboard
          )
        end
      rescue StandardError => e
        bot.api.send_message(chat_id: chat_id, text: "Ошибка: #{e.message}")
      end

      def show_table(bot, chat_id, game)
        unless game
          bot.api.send_message(chat_id: chat_id, text: 'Нет активной игры')
          return
        end

        table = format_score_table(game)
        bot.api.send_message(
          chat_id: chat_id,
          text: "```\n#{table}\n```",
          parse_mode: 'MarkdownV2'
        )
      end

      def show_current_state(bot, chat_id, game)
        unless game
          bot.api.send_message(chat_id: chat_id, text: 'Нет активной игры')
          return
        end

        if game.state == :waiting_for_players
          players = game.players.empty? ? 'Нет игроков' : game.players.map(&:name).join(', ')
          text = "Ожидание игроков\nТекущие игроки: #{players}"
        else
          text = "Идёт игра\nХод: #{game.current_player.name}"
          if game.dice.rolled?
            text += "\n\nВыпало: #{game.dice.to_emojis}\n#{game.dice.values.join(' ')}"
            text += "\nПеребросов осталось: #{game.dice.rolls_left}"
          end
        end

        bot.api.send_message(chat_id: chat_id, text: text)
      end

      def show_stats(bot, chat_id, user, persistence)
        stats = persistence.get_player_stats(user.first_name)

        text = <<~STATS
          Статистика игрока #{user.first_name}:

          Игр сыграно: #{stats[:games_played]}
          Средний счёт: #{stats[:average_score]}
          Лучший результат: #{stats[:highest_score] || 0}
          Побед: #{stats[:wins]}
        STATS

        bot.api.send_message(chat_id: chat_id, text: text)
      end

      def show_leaderboard(bot, chat_id, persistence)
        leaders = persistence.get_leaderboard(10)

        if leaders.empty?
          bot.api.send_message(chat_id: chat_id, text: 'Пока нет данных для таблицы лидеров')
          return
        end

        text = "Таблица лидеров:\n\n"
        leaders.each_with_index do |player, index|
          medal = case index
                  when 0 then '1.'
                  when 1 then '2.'
                  when 2 then '3.'
                  else "#{index + 1}."
                  end

          text += "#{medal} #{player[:player_name]}: #{player[:wins]} побед, " \
                  "ср.счёт #{player[:avg_score].round(0)}\n"
        end

        bot.api.send_message(chat_id: chat_id, text: text)
      end

      def stop_game(bot, chat_id, game, persistence)
        if game
          game.finish
          persistence.delete_game(chat_id)
        end

        bot.api.send_message(
          chat_id: chat_id,
          text: 'Игра завершена. Используйте /new чтобы начать новую игру.'
        )
      end

      def send_help(bot, chat_id)
        text = File.read('config/help.txt')
        bot.api.send_message(chat_id: chat_id, text: text)
      rescue Errno::ENOENT
        bot.api.send_message(chat_id: chat_id, text: default_help_text)
      end

      def send_rules(bot, chat_id)
        text = File.read('config/rules.txt')
        bot.api.send_message(chat_id: chat_id, text: text)
      rescue Errno::ENOENT
        bot.api.send_message(chat_id: chat_id, text: default_rules_text)
      end

      def send_categories(bot, chat_id)
        text = "Категории:\n\n"
        CATEGORY_NAMES.each do |num, name|
          text += "#{num}. #{name}\n"
        end

        bot.api.send_message(chat_id: chat_id, text: text)
      end

      def handle_unknown(bot, chat_id)
        bot.api.send_message(
          chat_id: chat_id,
          text: "Неизвестная команда. Используйте /help для списка команд."
        )
      end

      def valid_game_state?(bot, chat_id, game, check_dice: false)
        unless game
          bot.api.send_message(chat_id: chat_id, text: 'Сначала создайте игру с помощью /new')
          return false
        end

        if game.state != :in_progress
          bot.api.send_message(chat_id: chat_id, text: 'Игра ещё не началась!')
          return false
        end

        if check_dice && !game.dice.rolled?
          bot.api.send_message(chat_id: chat_id, text: 'Сначала бросьте кубики с помощью /roll')
          return false
        end

        true
      end

      def handle_game_over(bot, chat_id, game, text)
        winner = game.winner
        game.finish

        if winner.is_a?(Array)
          text += "\n\nНичья! Победители: #{winner.map(&:name).join(', ')}"
        else
          text += "\n\nПобедитель: #{winner.name}!"
        end

        text += "\n\nИспользуйте /new чтобы начать новую игру."

        bot.api.send_message(chat_id: chat_id, text: text)
        show_table(bot, chat_id, game)
      end

      def format_score_table(game)
        header = "Категория".ljust(25)
        game.players.each { |p| header += " #{p.name[0..7].ljust(8)}" }
        header += "\n" + "-" * (25 + game.players.size * 9)

        rows = []
        categories = [
          'Единицы', 'Двойки', 'Тройки', 'Четвёрки', 'Пятёрки', 'Шестёрки',
          'Верхний Балл', 'Бонус (35)', 'Три равных', 'Четыре равных',
          'Фул-хаус', 'Малая посл.', 'Большая посл.', 'Yahtzee', 'Шанс',
          'Нижний Балл', 'ИТОГО'
        ]

        categories.each_with_index do |cat, idx|
          row = cat.ljust(25)
          game.players.each do |player|
            score = player.scores[idx]
            row += " #{score.to_s.ljust(8)}"
          end
          rows << row
        end

        [header, *rows].join("\n")
      end

      def default_help_text
        <<~HELP
          Yahtzee - Помощь

          Основные команды:
          /new - Создать новую игру
          /join [имя] - Присоединиться к игре
          /start_game - Начать игру
          /roll - Бросить все кубики
          /reroll [позиции] - Перебросить кубики (например: /reroll 1 3 5)
          /score [1-13] - Выбрать категорию
          /table - Показать таблицу
          /current - Текущее состояние игры
          /categories - Список категорий
          /stats - Ваша статистика
          /leaderboard - Таблица лидеров
          /rules - Правила игры
          /stop - Завершить игру
        HELP
      end

      def default_rules_text
        <<~RULES
          Правила игры Yahtzee

          Цель игры - набрать максимальное количество очков, заполняя категории.

          Ход игры:
          1. Бросьте 5 кубиков (/roll)
          2. Можете перебросить любые кубики до 2 раз (/reroll)
          3. Выберите категорию для записи очков (/score)

          Верхняя секция (категории 1-6):
          Сумма соответствующих значений на кубиках.
          Если сумма верхней секции >= 63, вы получаете бонус 35 очков.

          Нижняя секция (категории 7-13):
          - Три равных: 3+ одинаковых кубика - сумма всех кубиков
          - Четыре равных: 4+ одинаковых кубика - сумма всех кубиков
          - Фул-хаус: 3 одинаковых + 2 одинаковых - 25 очков
          - Малая последовательность: 4+ последовательных - 30 очков
          - Большая последовательность: 5 последовательных - 40 очков
          - Yahtzee: 5 одинаковых - 50 очков
          - Шанс: любая комбинация - сумма всех кубиков

          Каждую категорию можно использовать только один раз!
        RULES
      end
    end
  end
end