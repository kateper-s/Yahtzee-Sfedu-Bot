# frozen_string_literal: true

require 'telegram/bot'
require 'dotenv/load'
require_relative '../yahtzee/game'
require_relative '../yahtzee/persistence'
require_relative 'keyboard'
require_relative 'message_handler'

module YahtzeeBot
  class Bot
    def initialize
      @token = ENV.fetch('TELEGRAM_BOT_TOKEN')
      @persistence = Yahtzee::Persistence.new
      @games = {}
    end

    def run
      puts "🚀 Бот запущен. Токен: #{@token[0..10]}..."

      Telegram::Bot::Client.run(@token) do |bot|
        bot.listen do |update|
          puts "Получен апдейт типа: #{update.class}"

          Thread.new do
            case update
            when Telegram::Bot::Types::Message
              handle_message(bot, update)
            when Telegram::Bot::Types::CallbackQuery
              handle_callback(bot, update)
            end
          rescue StandardError => e
            handle_error(bot, update, e)
          end
        end
      end
    end

    private

    def handle_message(bot, message)
      puts "Обработка сообщения: #{message.text}"
      chat_id = message.chat.id
      load_game(chat_id)

      result = MessageHandler.handle(bot, message, @games[chat_id], @persistence)

      @games[chat_id] = result if result.is_a?(Yahtzee::Game)
      save_game(chat_id) if @games[chat_id]
    end

    def handle_callback(bot, callback)
      puts "🔘 Обработка callback: #{callback.data}"
      puts "Текущие игры в памяти: #{@games.keys}"
      chat_id = callback.message.chat.id

      load_game(chat_id)
      puts "После load_game game=#{@games[chat_id]&.object_id}"

      result = MessageHandler.handle_callback(bot, callback, @games[chat_id], @persistence)
      puts "handle_callback вернул #{result.class}, object_id=#{result&.object_id}"

      if result.is_a?(Yahtzee::Game)
        @games[chat_id] = result
        puts "✅ Сохранено в @games[#{chat_id}] = #{result.object_id}"
      end

      save_game(chat_id) if @games[chat_id]
    rescue StandardError => e
      puts "❌ Ошибка в callback: #{e.message}"
      puts e.backtrace
      bot.api.answer_callback_query(
        callback_query_id: callback.id,
        text: "Ошибка: #{e.message}",
        show_alert: true
      )
    end

    def load_game(chat_id)
      return if @games[chat_id]

      puts "Загружаем игру из БД для чата #{chat_id}"
      saved_game = @persistence.load_game(chat_id)
      @games[chat_id] = saved_game if saved_game
      puts "Загружена игра: #{@games[chat_id]&.object_id}"
    end

    def save_game(chat_id)
      game = @games[chat_id]
      return unless game

      puts "Сохраняем игру #{game.object_id} в БД"
      @persistence.save_game(game)
    end

    def handle_error(bot, update, error)
      chat_id = if update.is_a?(Telegram::Bot::Types::Message)
                  update.chat.id
                elsif update.is_a?(Telegram::Bot::Types::CallbackQuery)
                  update.message.chat.id
                end

      return unless chat_id

      error_message = case error
                      when Yahtzee::Game::Error
                        "❌ #{error.message}"
                      else
                        "❌ Произошла ошибка. Пожалуйста, попробуйте снова.\n#{error.message}"
                      end

      bot.api.send_message(
        chat_id:,
        text: error_message
      )

      puts "Error: #{error.class} - #{error.message}"
      puts error.backtrace&.join("\n")
    end
  end
end
