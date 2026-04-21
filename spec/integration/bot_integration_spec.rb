# frozen_string_literal: true

require 'spec_helper'
require_relative '../../lib/yahtzee_bot/bot'

RSpec.describe 'YahtzeeBot Integration' do
  let(:bot) { instance_double(Telegram::Bot::Client) }
  let(:api) { instance_double(Telegram::Bot::Api) }
  let(:chat_id) { 123_456 }
  let(:message) { instance_double(Telegram::Bot::Types::Message, chat:, text:) }
  let(:chat) { instance_double(Telegram::Bot::Types::Chat, id: chat_id) }
  let(:from) { instance_double(Telegram::Bot::Types::User, first_name: 'Alice', id: 789) }

  before do
    allow(bot).to receive(:api).and_return(api)
    allow(api).to receive(:send_message)
    allow(message).to receive(:from).and_return(from)
  end

  describe 'game flow' do
    let(:text) { '/start' }

    it 'handles complete game session' do
      # Start new game
      expect(api).to receive(:send_message).with(
        chat_id:,
        text: /Добро пожаловать/
      )
      YahtzeeBot::MessageHandler.handle(bot, message)

      # Create new game
      allow(message).to receive(:text).and_return('/new')
      expect(api).to receive(:send_message).with(
        chat_id:,
        text: /Новая игра создана/
      )
      YahtzeeBot::MessageHandler.handle(bot, message)

      # Add players
      allow(message).to receive(:text).and_return('/join Alice')
      expect(api).to receive(:send_message).with(
        chat_id:,
        text: /Alice присоединился/
      )
      YahtzeeBot::MessageHandler.handle(bot, message)

      allow(message).to receive(:text).and_return('/join Bob')
      expect(api).to receive(:send_message).with(
        chat_id:,
        text: /Bob присоединился/
      )
      YahtzeeBot::MessageHandler.handle(bot, message)

      # Start game
      allow(message).to receive(:text).and_return('/start_game')
      expect(api).to receive(:send_message).with(
        chat_id:,
        text: /Игра начинается/
      )
      YahtzeeBot::MessageHandler.handle(bot, message)

      # Roll dice
      allow(message).to receive(:text).and_return('/roll')
      expect(api).to receive(:send_message).with(
        chat_id:,
        text: /бросает кубики/
      )
      YahtzeeBot::MessageHandler.handle(bot, message)

      # Select category
      allow(message).to receive(:text).and_return('/score 13')
      expect(api).to receive(:send_message).with(
        chat_id:,
        text: /выбрал категорию/
      )
      YahtzeeBot::MessageHandler.handle(bot, message)
    end
  end

  describe 'error handling' do
    it 'handles invalid commands gracefully' do
      allow(message).to receive(:text).and_return('/invalid_command')

      expect(api).to receive(:send_message).with(
        chat_id:,
        text: /Неизвестная команда/
      )

      YahtzeeBot::MessageHandler.handle(bot, message)
    end

    it 'prevents actions when game not started' do
      allow(message).to receive(:text).and_return('/roll')

      expect(api).to receive(:send_message).with(
        chat_id:,
        text: /Игра ещё не началась/
      )

      YahtzeeBot::MessageHandler.handle(bot, message)
    end
  end
end
