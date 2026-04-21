# frozen_string_literal: true

module YahtzeeBot
  class Keyboard
    class << self
      def join_keyboard
        Telegram::Bot::Types::ReplyKeyboardMarkup.new(
          keyboard: [
            [{ text: '/join ' }]
          ],
          resize_keyboard: true,
          one_time_keyboard: false
        )
      end

      def start_game_keyboard
        Telegram::Bot::Types::ReplyKeyboardMarkup.new(
          keyboard: [
            [{ text: '/start_game' }]
          ],
          resize_keyboard: true,
          one_time_keyboard: true
        )
      end

      def game_keyboard
        Telegram::Bot::Types::ReplyKeyboardMarkup.new(
          keyboard: [
            [{ text: '/roll' }, { text: '/table' }],
            [{ text: '/categories' }, { text: '/current' }],
            [{ text: '/help' }]
          ],
          resize_keyboard: true,
          one_time_keyboard: false
        )
      end

      def roll_keyboard(rolls_left)
        buttons = []
        buttons << [{ text: '/reroll 1 2 3 4 5' }] if rolls_left.positive?
        buttons << [{ text: '/score' }]
        buttons << [{ text: '/table' }, { text: '/categories' }]

        Telegram::Bot::Types::ReplyKeyboardMarkup.new(
          keyboard: buttons,
          resize_keyboard: true,
          one_time_keyboard: false
        )
      end

      def category_keyboard(available_categories)
        buttons = available_categories.each_slice(3).map do |slice|
          slice.map { |cat| { text: "/score #{cat}" } }
        end

        Telegram::Bot::Types::InlineKeyboardMarkup.new(
          inline_keyboard: buttons
        )
      end
    end
  end
end
