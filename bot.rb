# frozen_string_literal: true

require_relative 'lib/yahtzee_bot/bot'

if __FILE__ == $PROGRAM_NAME
  bot = YahtzeeBot::Bot.new
  bot.run
end