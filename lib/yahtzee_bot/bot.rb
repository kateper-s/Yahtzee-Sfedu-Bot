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
      Telegram::Bot::Client.run(@token) do |bot|
        bot.listen do |message|
          Thread.new { handle_message(bot, message) }
        rescue StandardError => e
          handle_error(bot, message, e)
        end
      end
    end

    private

    def handle_message(bot, message)
      return unless message.is_a?(Telegram::Bot::Types::Message)

      chat_id = message.chat.id
      load_game(chat_id)

      response = MessageHandler.handle(bot, message, @games[chat_id], @persistence)

      save_game(chat_id) if @games[chat_id]
      response
    end

    def load_game(chat_id)
      return if @games[chat_id]

      saved_game = @persistence.load_game(chat_id)
      @games[chat_id] = saved_game if saved_game
    end

    def save_game(chat_id)
      game = @games[chat_id]
      return unless game

      @persistence.save_game(game)
    end

    def handle_error(bot, message, error)
      return unless message&.chat&.id

      error_message = case error
                      when Yahtzee::Game::Error
                        "❌ #{error.message}"
                      else
                        "❌ Произошла ошибка. Пожалуйста, попробуйте снова.\n#{error.message}"
                      end

      bot.api.send_message(
        chat_id: message.chat.id,
        text: error_message
      )

      puts "Error: #{error.class} - #{error.message}"
      puts error.backtrace.join("\n")
    end
  end
end