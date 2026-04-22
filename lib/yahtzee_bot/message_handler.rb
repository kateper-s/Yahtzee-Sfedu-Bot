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

        case text
        when '/start'
          send_welcome(bot, chat_id)
        when '/new'
          create_new_game(bot, chat_id, game, persistence)
        when '/help'
          send_help(bot, chat_id)
        when '/rules'
          send_rules(bot, chat_id)
        when '/stop'
          stop_game(bot, chat_id, game, persistence)
        when '/menu'
          show_main_menu(bot, chat_id, game)
        else
          show_main_menu(bot, chat_id, game) if !text.empty? && text != '/start'
        end
      end

      def handle_callback(bot, callback, game, persistence)
        chat_id = callback.message.chat.id
        data = callback.data
        user = callback.from
        result = nil

        case data
        when 'new_game'
          result = create_new_game(bot, chat_id, game, persistence, callback)
        when 'join_game'
          prompt_join_game(bot, chat_id, game, callback)
        when 'start_game'
          start_game(bot, chat_id, game, callback)
        when 'roll'
          roll_dice(bot, chat_id, game, callback)
        when 'table'
          show_table(bot, chat_id, game, callback)
        when 'categories'
          send_categories(bot, chat_id, callback)
        when 'current'
          show_current_state(bot, chat_id, game, callback)
        when 'stats'
          show_stats(bot, chat_id, user, persistence, callback)
        when 'leaderboard'
          show_leaderboard(bot, chat_id, persistence, callback)
        when 'rules'
          send_rules(bot, chat_id, callback)
        when 'help'
          send_help(bot, chat_id, callback)
        when 'stop_game'
          stop_game(bot, chat_id, game, persistence, callback)
        when 'main_menu'
          show_main_menu(bot, chat_id, game, callback)
        when /^reroll_/
          positions = data.split('_')[1].chars.map(&:to_i)
          reroll_dice(bot, chat_id, game, positions, callback)
        when /^score_(\d+)$/
          category = ::Regexp.last_match(1).to_i
          select_category(bot, chat_id, game, category, callback)
        when /^join_name_(.+)$/
          name = ::Regexp.last_match(1)
          result = join_game(bot, chat_id, game, name, user, callback)
        end

        bot.api.answer_callback_query(callback_query_id: callback.id)
        result
      rescue StandardError => e
        bot.api.answer_callback_query(
          callback_query_id: callback.id,
          text: "Ошибка: #{e.message}",
          show_alert: true
        )
        nil
      end

      private

      def send_welcome(bot, chat_id)
        text = <<~WELCOME
          🎲 Добро пожаловать в Yahtzee!

          Это классическая игра в кости, где нужно набирать комбинации и зарабатывать очки.

          Используйте кнопки меню для управления игрой.
        WELCOME

        bot.api.send_message(
          chat_id:,
          text:,
          reply_markup: main_menu_keyboard
        )
      end

      def show_main_menu(bot, chat_id, game = nil, callback = nil)
        text = if game && game.state == :in_progress
                 "🎮 Текущая игра в процессе\nХод: #{game.current_player.name}"
               elsif game&.players&.any?
                 "🎲 Игра создана\nИгроки: #{game.players.map(&:name).join(', ')}"
               else
                 "🏠 Главное меню\nВыберите действие:"
               end

        keyboard = if game && game.state == :in_progress
                     game_keyboard
                   elsif game&.players&.any?
                     waiting_keyboard
                   else
                     main_menu_keyboard
                   end

        if callback
          bot.api.edit_message_text(
            chat_id:,
            message_id: callback.message.message_id,
            text:,
            reply_markup: keyboard
          )
        else
          bot.api.send_message(
            chat_id:,
            text:,
            reply_markup: keyboard
          )
        end
      end

      def main_menu_keyboard
        Telegram::Bot::Types::InlineKeyboardMarkup.new(
          inline_keyboard: [
            [{ text: '🎲 Новая игра', callback_data: 'new_game' }],
            [{ text: '📊 Статистика', callback_data: 'stats' },
             { text: '🏆 Таблица лидеров', callback_data: 'leaderboard' }],
            [{ text: '📖 Правила', callback_data: 'rules' },
             { text: '❓ Помощь', callback_data: 'help' }]
          ]
        )
      end

      def waiting_keyboard
        Telegram::Bot::Types::InlineKeyboardMarkup.new(
          inline_keyboard: [
            [{ text: '➕ Присоединиться', callback_data: 'join_game' }],
            [{ text: '🚀 Начать игру', callback_data: 'start_game' }],
            [{ text: '🗑 Отменить игру', callback_data: 'stop_game' }],
            [{ text: '🏠 Главное меню', callback_data: 'main_menu' }]
          ]
        )
      end

      def game_keyboard
        Telegram::Bot::Types::InlineKeyboardMarkup.new(
          inline_keyboard: [
            [{ text: '🎲 Бросить кубики', callback_data: 'roll' }],
            [{ text: '🎯 Выбрать категорию', callback_data: 'categories' }],
            [{ text: '📊 Таблица очков', callback_data: 'table' },
             { text: 'ℹ️ Текущий ход', callback_data: 'current' }],
            [{ text: '🏠 Главное меню', callback_data: 'main_menu' }]
          ]
        )
      end

      def roll_keyboard(rolls_left)
        buttons = []

        if rolls_left.positive?
          reroll_buttons = [
            { text: '🔄 Перебросить', callback_data: 'reroll_' }
          ]
          buttons << reroll_buttons
        end

        buttons << [{ text: '🎯 Выбрать категорию', callback_data: 'categories' }]
        buttons << [{ text: '📊 Таблица очков', callback_data: 'table' }]
        buttons << [{ text: '🏠 Главное меню', callback_data: 'main_menu' }]

        Telegram::Bot::Types::InlineKeyboardMarkup.new(inline_keyboard: buttons)
      end

      def reroll_selection_keyboard
        buttons = (1..5).map do |i|
          { text: "🎲 #{i}", callback_data: "reroll_#{i}" }
        end

        Telegram::Bot::Types::InlineKeyboardMarkup.new(
          inline_keyboard: [
            buttons,
            [{ text: '✅ Готово', callback_data: 'roll' }],
            [{ text: '🏠 Главное меню', callback_data: 'main_menu' }]
          ]
        )
      end

      def category_keyboard(available_categories)
        buttons = available_categories.map do |cat|
          { text: "#{cat}. #{CATEGORY_NAMES[cat]}", callback_data: "score_#{cat}" }
        end

        Telegram::Bot::Types::InlineKeyboardMarkup.new(
          inline_keyboard: buttons.each_slice(2).to_a + [[{ text: '🏠 Главное меню', callback_data: 'main_menu' }]]
        )
      end

      def create_new_game(bot, chat_id, game, persistence, callback = nil)
        if game
          game.finish
          persistence.delete_game(chat_id)
        end

        new_game = Yahtzee::Game.new(chat_id:)

        text = "🎲 Новая игра создана!\n\nИспользуйте кнопки ниже для управления:"

        if callback
          bot.api.edit_message_text(
            chat_id:,
            message_id: callback.message.message_id,
            text:,
            reply_markup: waiting_keyboard
          )
        else
          bot.api.send_message(
            chat_id:,
            text:,
            reply_markup: waiting_keyboard
          )
        end

        new_game
      end

      def prompt_join_game(bot, chat_id, game, callback)
        unless game
          bot.api.answer_callback_query(
            callback_query_id: callback.id,
            text: 'Сначала создайте игру через меню',
            show_alert: true
          )
          return
        end

        text = "Введите ваше имя для игры:\n(или используйте кнопки ниже)"

        keyboard = Telegram::Bot::Types::InlineKeyboardMarkup.new(
          inline_keyboard: [
            [{ text: '👤 Игрок', callback_data: 'join_name_Игрок' },
             { text: '🎲 Любитель', callback_data: 'join_name_Любитель' }],
            [{ text: '⭐ Чемпион', callback_data: 'join_name_Чемпион' },
             { text: '🎯 Стратег', callback_data: 'join_name_Стратег' }],
            [{ text: '🏠 Главное меню', callback_data: 'main_menu' }]
          ]
        )

        bot.api.edit_message_text(
          chat_id:,
          message_id: callback.message.message_id,
          text:,
          reply_markup: keyboard
        )
      end

      def join_game(bot, chat_id, game, name, user, callback = nil)
        unless game
          bot.api.answer_callback_query(
            callback_query_id: callback.id,
            text: 'Сначала создайте игру через меню',
            show_alert: true
          )
          return nil
        end

        begin
          player = game.add_player(name, user.id)
          players_list = game.players.map(&:name).join(', ')

          text = "✅ #{player.name} присоединился к игре!\n\n👥 Игроки: #{players_list}"

          # Всегда показываем клавиатуру ожидания (кнопки присоединения/начала игры)
          keyboard = waiting_keyboard

          if callback
            bot.api.edit_message_text(
              chat_id:,
              message_id: callback.message.message_id,
              text:,
              reply_markup: keyboard
            )
          else
            bot.api.send_message(chat_id:, text:, reply_markup: keyboard)
          end

          # Уведомление об успешном добавлении
          bot.api.answer_callback_query(
            callback_query_id: callback.id,
            text: "Игрок #{name} добавлен!",
            show_alert: false
          )

          game # возвращаем игру для сохранения в bot.rb
        rescue StandardError => e
          bot.api.answer_callback_query(
            callback_query_id: callback.id,
            text: "Ошибка: #{e.message}",
            show_alert: true
          )
          nil
        end
      end

      def start_game(bot, chat_id, game, callback = nil)
        unless game
          bot.api.answer_callback_query(
            callback_query_id: callback.id,
            text: 'Игра не найдена',
            show_alert: true
          )
          return
        end

        begin
          game.start
          current = game.current_player

          text = "🚀 Игра начинается!\n\n🎲 Ход игрока: #{current.name}\n\nНажмите 'Бросить кубики' чтобы начать ход."

          if callback
            bot.api.edit_message_text(
              chat_id:,
              message_id: callback.message.message_id,
              text:,
              reply_markup: game_keyboard
            )
          else
            bot.api.send_message(
              chat_id:,
              text:,
              reply_markup: game_keyboard
            )
          end
        rescue StandardError => e
          bot.api.answer_callback_query(
            callback_query_id: callback.id,
            text: "Ошибка: #{e.message}",
            show_alert: true
          )
        end
      end

      def roll_dice(bot, chat_id, game, callback = nil)
        return unless valid_game_state?(bot, chat_id, game, callback)

        begin
          dice_values = game.roll_dice
          emojis = game.dice.to_emojis

          text = "🎲 #{game.current_player.name} бросает кубики:\n\n" \
                 "#{emojis}\n`#{dice_values.join(' ')}`\n\n"

          if game.dice.can_roll?
            text += "🔄 Осталось перебросов: #{game.dice.rolls_left}\n" \
                    'Выберите кубики для переброса:'

            keyboard = reroll_selection_keyboard
          else
            text += "❌ Перебросов не осталось!\n" \
                    'Выберите категорию для записи очков:'
            keyboard = category_keyboard(game.current_player.available_categories)
          end

          if callback
            bot.api.edit_message_text(
              chat_id:,
              message_id: callback.message.message_id,
              text:,
              parse_mode: 'Markdown',
              reply_markup: keyboard
            )
          else
            bot.api.send_message(
              chat_id:,
              text:,
              parse_mode: 'Markdown',
              reply_markup: keyboard
            )
          end
        rescue StandardError => e
          bot.api.answer_callback_query(
            callback_query_id: callback.id,
            text: "Ошибка: #{e.message}",
            show_alert: true
          )
        end
      end

      def reroll_dice(bot, chat_id, game, positions, callback = nil)
        return unless valid_game_state?(bot, chat_id, game, callback)

        begin
          dice_values = game.reroll_dice(positions)
          emojis = game.dice.to_emojis

          text = "🔄 #{game.current_player.name} перебрасывает кубики #{positions.join(', ')}:\n\n" \
                 "#{emojis}\n`#{dice_values.join(' ')}`\n\n"

          if game.dice.can_roll?
            text += "🔄 Осталось перебросов: #{game.dice.rolls_left}\n" \
                    'Выберите кубики для переброса:'
            keyboard = reroll_selection_keyboard
          else
            text += "❌ Перебросов не осталось!\n" \
                    'Выберите категорию для записи очков:'
            keyboard = category_keyboard(game.current_player.available_categories)
          end

          if callback
            bot.api.edit_message_text(
              chat_id:,
              message_id: callback.message.message_id,
              text:,
              parse_mode: 'Markdown',
              reply_markup: keyboard
            )
          else
            bot.api.send_message(
              chat_id:,
              text:,
              parse_mode: 'Markdown',
              reply_markup: keyboard
            )
          end
        rescue StandardError => e
          bot.api.answer_callback_query(
            callback_query_id: callback.id,
            text: "Ошибка: #{e.message}",
            show_alert: true
          )
        end
      end

      def select_category(bot, chat_id, game, category, callback = nil)
        return unless valid_game_state?(bot, chat_id, game, callback, true)

        unless category.between?(1, 13)
          bot.api.answer_callback_query(
            callback_query_id: callback.id,
            text: 'Неверная категория',
            show_alert: true
          )
          return
        end

        begin
          player_name = game.current_player.name
          points = game.select_category(category, player_name)

          category_name = CATEGORY_NAMES[category]
          text = "✅ #{player_name} выбрал категорию: #{category_name}\n" \
                 "🏆 Набрано очков: #{points}\n"

          if game.game_over?
            handle_game_over(bot, chat_id, game, text, callback)
          else
            text += "\n🎲 Следующий ход: #{game.current_player.name}\n" \
                    "Нажмите 'Бросить кубики' чтобы начать ход."

            if callback
              bot.api.edit_message_text(
                chat_id:,
                message_id: callback.message.message_id,
                text:,
                reply_markup: game_keyboard
              )
            else
              bot.api.send_message(
                chat_id:,
                text:,
                reply_markup: game_keyboard
              )
            end
          end
        rescue StandardError => e
          bot.api.answer_callback_query(
            callback_query_id: callback.id,
            text: "Ошибка: #{e.message}",
            show_alert: true
          )
        end
      end

      def show_table(bot, chat_id, game, callback = nil)
        unless game
          bot.api.answer_callback_query(
            callback_query_id: callback.id,
            text: 'Нет активной игры',
            show_alert: true
          )
          return
        end

        table = format_score_table(game)

        keyboard = Telegram::Bot::Types::InlineKeyboardMarkup.new(
          inline_keyboard: [
            [{ text: '🏠 Главное меню', callback_data: 'main_menu' }]
          ]
        )

        if callback
          bot.api.edit_message_text(
            chat_id:,
            message_id: callback.message.message_id,
            text: "```\n#{table}\n```",
            parse_mode: 'Markdown',
            reply_markup: keyboard
          )
        else
          bot.api.send_message(
            chat_id:,
            text: "```\n#{table}\n```",
            parse_mode: 'Markdown',
            reply_markup: keyboard
          )
        end
      end

      def show_current_state(bot, chat_id, game, callback = nil)
        unless game
          bot.api.answer_callback_query(
            callback_query_id: callback.id,
            text: 'Нет активной игры',
            show_alert: true
          )
          return
        end

        if game.state == :waiting_for_players
          players = game.players.empty? ? 'Нет игроков' : game.players.map(&:name).join(', ')
          text = "⏳ Ожидание игроков\n👥 Текущие игроки: #{players}"
        else
          text = "🎮 Идёт игра\n🎲 Ход: #{game.current_player.name}"
          if game.dice.rolled?
            text += "\n\n🎲 Выпало: #{game.dice.to_emojis}\n`#{game.dice.values.join(' ')}`"
            text += "\n🔄 Перебросов осталось: #{game.dice.rolls_left}"
          end
        end

        keyboard = Telegram::Bot::Types::InlineKeyboardMarkup.new(
          inline_keyboard: [
            [{ text: '🏠 Главное меню', callback_data: 'main_menu' }]
          ]
        )

        if callback
          bot.api.edit_message_text(
            chat_id:,
            message_id: callback.message.message_id,
            text:,
            parse_mode: 'Markdown',
            reply_markup: keyboard
          )
        else
          bot.api.send_message(
            chat_id:,
            text:,
            parse_mode: 'Markdown',
            reply_markup: keyboard
          )
        end
      end

      def show_stats(bot, chat_id, user, persistence, callback = nil)
        stats = persistence.get_player_stats(user.first_name)

        text = <<~STATS
          📊 Статистика игрока #{user.first_name}:

          🎮 Игр сыграно: #{stats[:games_played]}
          📈 Средний счёт: #{stats[:average_score]}
          🏆 Лучший результат: #{stats[:highest_score] || 0}
          ⭐ Побед: #{stats[:wins]}
        STATS

        keyboard = Telegram::Bot::Types::InlineKeyboardMarkup.new(
          inline_keyboard: [
            [{ text: '🏠 Главное меню', callback_data: 'main_menu' }]
          ]
        )

        if callback
          bot.api.edit_message_text(
            chat_id:,
            message_id: callback.message.message_id,
            text:,
            reply_markup: keyboard
          )
        else
          bot.api.send_message(chat_id:, text:, reply_markup: keyboard)
        end
      end

      def show_leaderboard(bot, chat_id, persistence, callback = nil)
        leaders = persistence.get_leaderboard(10)

        if leaders.empty?
          text = '📊 Пока нет данных для таблицы лидеров'
        else
          text = "🏆 Таблица лидеров:\n\n"
          leaders.each_with_index do |player, index|
            medal = case index
                    when 0 then '🥇'
                    when 1 then '🥈'
                    when 2 then '🥉'
                    else "#{index + 1}."
                    end

            text += "#{medal} #{player[:player_name]}: #{player[:wins]} побед, " \
                    "ср.счёт #{player[:avg_score].round(0)}\n"
          end
        end

        keyboard = Telegram::Bot::Types::InlineKeyboardMarkup.new(
          inline_keyboard: [
            [{ text: '🏠 Главное меню', callback_data: 'main_menu' }]
          ]
        )

        if callback
          bot.api.edit_message_text(
            chat_id:,
            message_id: callback.message.message_id,
            text:,
            reply_markup: keyboard
          )
        else
          bot.api.send_message(chat_id:, text:, reply_markup: keyboard)
        end
      end

      def stop_game(bot, chat_id, game, persistence, callback = nil)
        if game
          game.finish
          persistence.delete_game(chat_id)
        end

        text = '🛑 Игра завершена. Используйте меню чтобы начать новую игру.'

        if callback
          bot.api.edit_message_text(
            chat_id:,
            message_id: callback.message.message_id,
            text:,
            reply_markup: main_menu_keyboard
          )
        else
          bot.api.send_message(
            chat_id:,
            text:,
            reply_markup: main_menu_keyboard
          )
        end
      end

      def send_help(bot, chat_id, callback = nil)
        text = default_help_text

        keyboard = Telegram::Bot::Types::InlineKeyboardMarkup.new(
          inline_keyboard: [
            [{ text: '🏠 Главное меню', callback_data: 'main_menu' }]
          ]
        )

        if callback
          bot.api.edit_message_text(
            chat_id:,
            message_id: callback.message.message_id,
            text:,
            reply_markup: keyboard
          )
        else
          bot.api.send_message(chat_id:, text:, reply_markup: keyboard)
        end
      end

      def send_rules(bot, chat_id, callback = nil)
        text = default_rules_text

        keyboard = Telegram::Bot::Types::InlineKeyboardMarkup.new(
          inline_keyboard: [
            [{ text: '🏠 Главное меню', callback_data: 'main_menu' }]
          ]
        )

        if callback
          bot.api.edit_message_text(
            chat_id:,
            message_id: callback.message.message_id,
            text:,
            reply_markup: keyboard
          )
        else
          bot.api.send_message(chat_id:, text:, reply_markup: keyboard)
        end
      end

      def send_categories(bot, chat_id, callback = nil)
        text = "📋 Категории:\n\n"
        CATEGORY_NAMES.each do |num, name|
          text += "#{num}. #{name}\n"
        end

        keyboard = Telegram::Bot::Types::InlineKeyboardMarkup.new(
          inline_keyboard: [
            [{ text: '🏠 Главное меню', callback_data: 'main_menu' }]
          ]
        )

        if callback
          bot.api.edit_message_text(
            chat_id:,
            message_id: callback.message.message_id,
            text:,
            reply_markup: keyboard
          )
        else
          bot.api.send_message(chat_id:, text:, reply_markup: keyboard)
        end
      end

      def valid_game_state?(bot, _chat_id, game, callback, check_dice: false)
        unless game
          bot.api.answer_callback_query(
            callback_query_id: callback.id,
            text: 'Сначала создайте игру через меню',
            show_alert: true
          )
          return false
        end

        if game.state != :in_progress
          bot.api.answer_callback_query(
            callback_query_id: callback.id,
            text: 'Игра ещё не началась!',
            show_alert: true
          )
          return false
        end

        if check_dice && !game.dice.rolled?
          bot.api.answer_callback_query(
            callback_query_id: callback.id,
            text: 'Сначала бросьте кубики',
            show_alert: true
          )
          return false
        end

        true
      end

      def handle_game_over(bot, chat_id, game, text, callback = nil)
        winner = game.winner
        game.finish

        text += if winner.is_a?(Array)
                  "\n\n🤝 Ничья! Победители: #{winner.map(&:name).join(', ')}"
                else
                  "\n\n🏆 Победитель: #{winner.name}!"
                end

        text += "\n\nИспользуйте меню чтобы начать новую игру."

        if callback
          bot.api.edit_message_text(
            chat_id:,
            message_id: callback.message.message_id,
            text:,
            reply_markup: main_menu_keyboard
          )
        else
          bot.api.send_message(
            chat_id:,
            text:,
            reply_markup: main_menu_keyboard
          )
        end

        show_table(bot, chat_id, game)
      end

      def format_score_table(game)
        header = 'Категория'.ljust(25)
        game.players.each { |p| header += " #{p.name[0..7].ljust(8)}" }
        header += "\n#{'-' * (25 + (game.players.size * 9))}"

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
          📚 **Помощь по игре Yahtzee**

          **Основные действия:**
          🎲 Используйте кнопки меню для управления игрой
          🎯 Выбирайте категории после броска кубиков
          🔄 Можно перебрасывать кубики до 2 раз

          **Категории:**
          1-6: Сумма соответствующих чисел
          7: Три равных - сумма всех кубиков
          8: Четыре равных - сумма всех кубиков
          9: Фул-хаус - 25 очков
          10: Малая последовательность - 30 очков
          11: Большая последовательность - 40 очков
          12: Yahtzee - 50 очков
          13: Шанс - сумма всех кубиков

          **Бонус:**
          При сумме верхней секции ≥63, добавляется 35 очков

          **Команды:**
          /start - Начать
          /new - Новая игра
          /menu - Главное меню
          /stop - Завершить игру
        HELP
      end

      def default_rules_text
        <<~RULES
          🎲 **Правила игры Yahtzee**

          **Цель игры:**
          Набрать максимальное количество очков, заполняя все категории.

          **Ход игры:**
          1. 🎲 Бросьте 5 кубиков
          2. 🔄 Можете перебросить любые кубики до 2 раз
          3. 📝 Выберите категорию для записи очков

          **Верхняя секция (1-6):**
          Сумма соответствующих значений на кубиках.
          Бонус 35 очков при сумме ≥ 63.

          **Нижняя секция (7-13):**
          • 7 - Три равных: 3+ одинаковых - сумма всех кубиков
          • 8 - Четыре равных: 4+ одинаковых - сумма всех кубиков
          • 9 - Фул-хаус: 3+2 одинаковых - 25 очков
          • 10 - Малая последовательность: 4+ подряд - 30 очков
          • 11 - Большая последовательность: 5 подряд - 40 очков
          • 12 - Yahtzee: 5 одинаковых - 50 очков
          • 13 - Шанс: любая комбинация - сумма всех кубиков

          **Важно:** Каждую категорию можно использовать только один раз!
        RULES
      end
    end
  end
end
