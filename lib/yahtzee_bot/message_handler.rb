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
          show_categories_with_scores(bot, chat_id, game, callback)
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
        when 'main_menu_root'
          show_main_menu(bot, chat_id, nil, callback)
        when 'reroll_start'
          show_reroll_selection(bot, chat_id, game, callback)
        when /^reroll_toggle_(\d+)$/
          position = ::Regexp.last_match(1).to_i
          toggle_reroll_position(bot, chat_id, game, position, callback)
        when 'reroll_confirm'
          confirm_reroll(bot, chat_id, game, callback)
        when /^score_(\d+)$/
          category = ::Regexp.last_match(1).to_i
          select_category(bot, chat_id, game, category, persistence, callback)
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

      def show_main_menu(bot, chat_id, game = nil, _callback = nil)
        if game && game.state == :in_progress
          if game.dice.rolled?
            keyboard = roll_keyboard(game.dice.rolls_left)
            text = "🎮 Текущая игра в процессе\nХод: #{game.current_player.name}\n\nКубики: #{game.dice.to_emojis}\nОсталось бросков: #{game.dice.rolls_left}"
          else
            keyboard = game_keyboard
            text = "🎮 Текущая игра в процессе\nХод: #{game.current_player.name}\n\nБросьте кубики чтобы начать ход."
          end
        elsif game&.players&.any?
          keyboard = waiting_keyboard
          text = "🎲 Игра создана\nИгроки: #{game.players.map(&:name).join(', ')}"
        else
          keyboard = main_menu_keyboard
          text = "🏠 Главное меню\nВыберите действие:"
        end

        bot.api.send_message(
          chat_id:,
          text:,
          reply_markup: keyboard,
          parse_mode: 'Markdown'
        )
        bot.api.send_message(
          chat_id:,
          text:,
          reply_markup: keyboard,
          parse_mode: 'Markdown'
        )
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
            [{ text: '🗑 Отменить игру', callback_data: 'stop_game' }]
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
            [{ text: '❓ Помощь', callback_data: 'help' },
             { text: '🛑 Завершить игру', callback_data: 'stop_game' }]
          ]
        )
      end

      def roll_keyboard(rolls_left)
        buttons = []

        if rolls_left.positive?
          buttons << [{ text: '🔄 Перебросить кубики', callback_data: 'reroll_start' }]
        end

        buttons << [{ text: '🎯 Выбрать категорию', callback_data: 'categories' }]
        buttons << [{ text: '📊 Таблица очков', callback_data: 'table' }]
        buttons << [{ text: '❓ Помощь', callback_data: 'help' },
                    { text: '🛑 Завершить игру', callback_data: 'stop_game' }]

        Telegram::Bot::Types::InlineKeyboardMarkup.new(inline_keyboard: buttons)
      end

      def reroll_selection_keyboard(selected_positions = [])
        buttons = (1..5).map do |i|
          is_selected = selected_positions.include?(i)
          emoji = is_selected ? '✅' : '🎲'
          { text: "#{emoji} #{i}", callback_data: "reroll_toggle_#{i}" }
        end

        Telegram::Bot::Types::InlineKeyboardMarkup.new(
          inline_keyboard: [
            buttons,
            [{ text: '✅ Перебросить', callback_data: 'reroll_confirm' }],
            [{ text: '❌ Отмена', callback_data: 'categories' }]
          ]
        )
      end

      def category_keyboard(available_categories, game = nil)
        buttons = available_categories.map do |cat|
          score_text = if game&.dice&.rolled?
                         score = Yahtzee::ScoreCalculator.calculate(cat, game.dice.values)
                         "#{cat}. #{CATEGORY_NAMES[cat]} (#{score}⭐)"
                       else
                         "#{cat}. #{CATEGORY_NAMES[cat]}"
                       end
          { text: score_text, callback_data: "score_#{cat}" }
        end

        Telegram::Bot::Types::InlineKeyboardMarkup.new(
          inline_keyboard: buttons.each_slice(1).to_a + [[{ text: '🎮 Вернуться в игру', callback_data: 'main_menu' }]]
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

        text = 'Выберите ваше имя: '

        keyboard = Telegram::Bot::Types::InlineKeyboardMarkup.new(
          inline_keyboard: [
            [{ text: '👤 Игрок', callback_data: 'join_name_Игрок' },
             { text: '🎲 Любитель', callback_data: 'join_name_Любитель' }],
            [{ text: '⭐ Чемпион', callback_data: 'join_name_Чемпион' },
             { text: '🎯 Стратег', callback_data: 'join_name_Стратег' }],
            [{ text: '🏠 Главное меню', callback_data: 'main_menu' }]
          ]
        )

        bot.api.send_message(
          chat_id:,
          text:,
          reply_markup: keyboard
        )
      end

      def join_game(bot, chat_id, game, name, user, callback)
        unless game
          bot.api.answer_callback_query(
            callback_query_id: callback.id,
            text: 'Сначала создайте игру через меню',
            show_alert: true
          )
          return nil
        end

        game.add_player(name, user.id)

        text = "✅ #{name} присоединился к игре!\n\nТекущие игроки: #{game.players.map(&:name).join(', ')}"

        bot.api.edit_message_text(
          chat_id:,
          message_id: callback.message.message_id,
          text:,
          reply_markup: waiting_keyboard
        )

        game
      end

      def start_game(bot, chat_id, game, callback)
        unless game
          bot.api.answer_callback_query(
            callback_query_id: callback.id,
            text: 'Сначала создайте игру через меню',
            show_alert: true
          )
          return nil
        end

        if game.state != :waiting_for_players
          bot.api.answer_callback_query(
            callback_query_id: callback.id,
            text: 'Игра уже началась или завершена',
            show_alert: true
          )
          return nil
        end

        if game.players.size < Yahtzee::Game::MIN_PLAYERS
          bot.api.answer_callback_query(
            callback_query_id: callback.id,
            text: "Нужно хотя бы #{Yahtzee::Game::MIN_PLAYERS} игрок(а)",
            show_alert: true
          )
          return nil
        end

        game.start

        text = "🎮 Игра началась!\n\n#{game.current_player.name}, ваш ход!\n\nБросьте кубики чтобы начать."

        bot.api.edit_message_text(
          chat_id:,
          message_id: callback.message.message_id,
          text:,
          reply_markup: game_keyboard
        )

        game
      end

      def roll_dice(bot, chat_id, game, callback)
        unless valid_game_state?(bot, chat_id, game, callback)
          return nil
        end

        game.roll_dice

        text = "🎲 #{game.current_player.name} бросил кубики:\n\n#{game.dice.to_emojis}\n\nОсталось бросков: #{game.dice.rolls_left}"

        bot.api.edit_message_text(
          chat_id:,
          message_id: callback.message.message_id,
          text:,
          reply_markup: roll_keyboard(game.dice.rolls_left)
        )

        game
      end

      def show_reroll_selection(bot, chat_id, game, callback)
        unless valid_game_state?(bot, chat_id, game, callback, check_dice: true)
          return nil
        end

        text = "🎲 Выберите кубики для переброски:\n\n#{game.dice.to_emojis}\n\nОсталось бросков: #{game.dice.rolls_left}"

        bot.api.edit_message_text(
          chat_id:,
          message_id: callback.message.message_id,
          text:,
          reply_markup: reroll_selection_keyboard([])
        )

        game
      end

      def toggle_reroll_position(bot, chat_id, game, position, callback)
        unless valid_game_state?(bot, chat_id, game, callback, check_dice: true)
          return nil
        end

        selected = callback.message.reply_markup.inline_keyboard[0]
                           .filter_map { |btn| btn.callback_data.match(/reroll_toggle_(\d+)/) { |m| m[1].to_i } if btn.text.include?('✅') }

        if selected.include?(position)
          selected.delete(position)
        else
          selected << position
        end

        text = "🎲 Выберите кубики для переброски:\n\n#{game.dice.to_emojis}\n\nВыбрано: #{selected.sort.join(', ')}\n\nОсталось бросков: #{game.dice.rolls_left}"

        bot.api.edit_message_text(
          chat_id:,
          message_id: callback.message.message_id,
          text:,
          reply_markup: reroll_selection_keyboard(selected)
        )

        game
      end

      def confirm_reroll(bot, chat_id, game, callback)
        unless valid_game_state?(bot, chat_id, game, callback, check_dice: true)
          return nil
        end

        selected = callback.message.reply_markup.inline_keyboard[0]
                           .filter_map { |btn| btn.callback_data.match(/reroll_toggle_(\d+)/) { |m| m[1].to_i } if btn.text.include?('✅') }

        if selected.empty?
          bot.api.answer_callback_query(
            callback_query_id: callback.id,
            text: 'Выберите хотя бы один кубик',
            show_alert: true
          )
          return nil
        end

        game.reroll_dice(selected)

        text = "🎲 #{game.current_player.name} перебросил кубики:\n\n#{game.dice.to_emojis}\n\nОсталось бросков: #{game.dice.rolls_left}"

        bot.api.edit_message_text(
          chat_id:,
          message_id: callback.message.message_id,
          text:,
          reply_markup: roll_keyboard(game.dice.rolls_left)
        )

        game
      end

      def show_categories_with_scores(bot, chat_id, game, callback)
        unless valid_game_state?(bot, chat_id, game, callback, check_dice: true)
          return nil
        end

        player = game.current_player
        text = "📋 Доступные категории (#{player.name}):\n\n"

        available = player.available_categories
        available.each do |cat|
          score = Yahtzee::ScoreCalculator.calculate(cat, game.dice.values)
          text += "#{cat}. #{CATEGORY_NAMES[cat]} — #{score} очков\n"
        end

        text += "\nТекущие кубики: #{game.dice.to_emojis}"

        bot.api.edit_message_text(
          chat_id:,
          message_id: callback.message.message_id,
          text:,
          reply_markup: category_keyboard(available, game)
        )

        game
      end

      def select_category(bot, chat_id, game, category, persistence, callback)
        unless valid_game_state?(bot, chat_id, game, callback, check_dice: true)
          return nil
        end

        player = game.current_player

        begin
          points = game.select_category(category, player.name)

          if game.game_over?
            text = "📊 #{player.name} выбрал категорию #{CATEGORY_NAMES[category]} и набрал #{points} очков!\n\n🎉 Игра закончена!"
            handle_game_over(bot, chat_id, game, text, persistence, callback)
          else
            next_player = game.current_player
            text = "✅ #{player.name} выбрал #{CATEGORY_NAMES[category]} (+#{points}⭐)\n\n🎮 Ход переходит к #{next_player.name}"

            bot.api.edit_message_text(
              chat_id:,
              message_id: callback.message.message_id,
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

        game
      end

      def format_upper_section(game)
        header = format_table_header(game)
        categories = ['Единицы', 'Двойки', 'Тройки', 'Четвёрки', 'Пятёрки', 'Шестёрки', 'Верхний Балл', 'Бонус (35)']
        rows = format_categories_rows(game, categories)
        "📊 *Верхняя секция*\n\n```\n#{header}\n#{rows}\n```"
      end

      def format_lower_section(game)
        header = format_table_header(game)
        categories = ['Три равных', 'Четыре равных', 'Фул-хаус', 'Малая посл.', 'Большая посл.', 'Yahtzee', 'Шанс', 'Нижний Балл', 'ИТОГО']
        rows = format_categories_rows(game, categories)
        "📊 *Нижняя секция*\n\n```\n#{header}\n#{rows}\n```"
      end

      def format_table_header(game)
        category_width = 20
        name_width = 8
        header = 'Категория'.ljust(category_width)
        game.players.each do |player|
          short_name = player.name[0...name_width]
          header += " #{short_name.ljust(name_width)}"
        end
        "#{header}\n#{'-' * (category_width + (game.players.size * (name_width + 1)))}"
      end

      def format_categories_rows(game, categories)
        category_width = 20
        name_width = 8
        rows = []
        categories.each do |cat|
          row = cat.ljust(category_width)
          game.players.each do |player|
            idx = find_category_index(cat)
            score = player.scores[idx]
            row += " #{score.to_s.rjust(name_width)}"
          end
          rows << row
        end
        rows.join("\n")
      end

      def find_category_index(cat_name)
        mapping = {
          'Единицы' => 0, 'Двойки' => 1, 'Тройки' => 2, 'Четвёрки' => 3,
          'Пятёрки' => 4, 'Шестёрки' => 5, 'Верхний Балл' => 6, 'Бонус (35)' => 7,
          'Три равных' => 8, 'Четыре равных' => 9, 'Фул-хаус' => 10,
          'Малая посл.' => 11, 'Большая посл.' => 12, 'Yahtzee' => 13,
          'Шанс' => 14, 'Нижний Балл' => 15, 'ИТОГО' => 16
        }
        mapping[cat_name]
      end

      def show_table(bot, chat_id, game, callback = nil)
        unless game
          if callback
            bot.api.answer_callback_query(
              callback_query_id: callback.id,
              text: 'Нет активной игры',
              show_alert: true
            )
          end
          return
        end

        upper_text = format_upper_section(game)
        lower_text = format_lower_section(game)

        return_keyboard = Telegram::Bot::Types::InlineKeyboardMarkup.new(
          inline_keyboard: [[{ text: '🎮 Вернуться в игру', callback_data: 'main_menu' }]]
        )

        if callback
          bot.api.edit_message_text(chat_id:, message_id: callback.message.message_id, text: upper_text, parse_mode: 'Markdown')
        else
          bot.api.send_message(chat_id:, text: upper_text, parse_mode: 'Markdown')
        end
        bot.api.send_message(chat_id:, text: lower_text, parse_mode: 'Markdown')
        bot.api.send_message(chat_id:, text: '📋 Таблица завершена. Выберите действие:', reply_markup: return_keyboard)
      end

      def show_current_state(bot, chat_id, game, callback)
        unless valid_game_state?(bot, chat_id, game, callback)
          return
        end

        player = game.current_player
        text = "ℹ️ **Информация о текущем ходе**\n\n"
        text += "👤 Игрок: #{player.name}\n"
        text += "🎲 Кубики: #{game.dice.rolled? ? game.dice.to_emojis : 'ещё не брошены'}\n"
        text += "📝 Бросков осталось: #{game.dice.rolls_left}\n"
        text += "📊 Категорий использовано: #{player.used_categories.size}/13\n"
        text += "⭐ Текущий счёт: #{player.total_score}"

        keyboard = Telegram::Bot::Types::InlineKeyboardMarkup.new(
          inline_keyboard: [
            [{ text: '🎮 Продолжить игру', callback_data: 'main_menu' }]
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

      def show_stats(bot, chat_id, user, persistence, callback)
        stats = persistence.get_player_stats(user.id)

        text = "📊 **Ваша статистика**\n\n"
        text += "🎮 Игр сыграно: #{stats[:games_played]}\n"
        text += "🏆 Побед: #{stats[:wins]}\n"
        text += "⭐ Средний счёт: #{stats[:average_score]}\n"
        text += "🔝 Высший счёт: #{stats[:highest_score]}"

        keyboard = Telegram::Bot::Types::InlineKeyboardMarkup.new(
          inline_keyboard: [
            [{ text: '🏠 Главное меню', callback_data: 'main_menu_root' }]  # изменено на main_menu_root
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

      def show_leaderboard(bot, chat_id, persistence, callback)
        leaderboard = persistence.get_leaderboard

        text = "🏆 **Таблица лидеров**\n\n"

        leaderboard.each_with_index do |player, idx|
          medal = case idx
                  when 0 then '🥇'
                  when 1 then '🥈'
                  when 2 then '🥉'
                  else "#{idx + 1}."
                  end

          text += "#{medal} #{player[:player_name]}: #{player[:wins]} побед, " \
                  "ср.счёт #{player[:avg_score].round(0)}\n"
        end

        keyboard = Telegram::Bot::Types::InlineKeyboardMarkup.new(
          inline_keyboard: [
            [{ text: '🏠 Главное меню', callback_data: 'main_menu_root' }]  # изменено на main_menu_root
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

      def stop_game(bot, chat_id, game, persistence, callback = nil)
        if game
          if game.players.any? && game.players.any? { |p| p.used_categories.any? }
            max_score = game.players.map(&:total_score).max
            winners = game.players.select { |p| p.total_score == max_score }
            game.players.each do |player|
              won = winners.include?(player)
              persistence.save_player_stats(player.id, player.name, player.total_score, won:)
            end
          end

          game.finish
          persistence.delete_game(chat_id)
        end

        text = '🛑 Игра завершена. Результаты сохранены. Используйте меню чтобы начать новую игру.'

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
            [{ text: '🏠 Главное меню', callback_data: 'main_menu_root' }]  # изменено на main_menu_root
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

      def send_rules(bot, chat_id, callback = nil)
        text = default_rules_text

        keyboard = Telegram::Bot::Types::InlineKeyboardMarkup.new(
          inline_keyboard: [
            [{ text: '🏠 Главное меню', callback_data: 'main_menu_root' }]  # изменено на main_menu_root
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

      def handle_game_over(bot, chat_id, game, text, persistence, callback = nil)
        winner = game.winner
        game.finish

        game.players.each do |player|
          won = if winner.is_a?(Array)
                  winner.include?(player)
                else
                  player == winner
                end
          persistence.save_player_stats(player.id, player.name, player.total_score, won:)
        end

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
          🔄 Можно перебрасывать кубики до 2 раз, выбирая несколько кубиков одновременно

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
          2. 🔄 Можете перебросить любые кубики до 2 раз (выбирайте сразу несколько)
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
