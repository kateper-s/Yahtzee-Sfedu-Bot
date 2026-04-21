# frozen_string_literal: true

require 'spec_helper'
require_relative '../../../lib/yahtzee_bot/bot'

RSpec.describe YahtzeeBot::Bot do
  let(:bot) { described_class.new }
  let(:telegram_bot) { instance_double(Telegram::Bot::Client) }
  let(:api) { instance_double(Telegram::Bot::Api) }
  let(:persistence) { instance_double(Yahtzee::Persistence) }

  before do
    allow(Yahtzee::Persistence).to receive(:new).and_return(persistence)
    allow(persistence).to receive(:load_game)
    allow(persistence).to receive(:save_game)
    allow(persistence).to receive(:delete_game)
  end

  describe '#initialize' do
    it 'initializes with token from ENV' do
      expect(bot.instance_variable_get(:@token)).to eq(ENV.fetch('TELEGRAM_BOT_TOKEN', nil))
    end

    it 'creates persistence instance' do
      expect(bot.instance_variable_get(:@persistence)).to eq(persistence)
    end

    it 'initializes empty games hash' do
      expect(bot.instance_variable_get(:@games)).to eq({})
    end
  end

  describe '#run' do
    let(:message) do
      instance_double(
        Telegram::Bot::Types::Message,
        chat: instance_double(Telegram::Bot::Types::Chat, id: 123_456),
        from: instance_double(Telegram::Bot::Types::User, first_name: 'Alice', id: 789),
        text: '/start'
      )
    end

    before do
      allow(Telegram::Bot::Client).to receive(:run).and_yield(telegram_bot)
      allow(telegram_bot).to receive(:listen).and_yield(message)
      allow(telegram_bot).to receive(:api).and_return(api)
      allow(api).to receive(:send_message)
    end

    it 'processes incoming messages' do
      expect(YahtzeeBot::MessageHandler).to receive(:handle)
        .with(telegram_bot, message, nil, persistence)

      bot.run
    end

    it 'loads saved game for chat' do
      saved_game = instance_double(Yahtzee::Game)
      allow(persistence).to receive(:load_game).with(123_456).and_return(saved_game)

      expect(YahtzeeBot::MessageHandler).to receive(:handle)
        .with(telegram_bot, message, saved_game, persistence)

      bot.run
    end

    it 'handles multiple messages concurrently' do
      messages = Array.new(3) { message }
      allow(telegram_bot).to receive(:listen).and_yield(messages[0])
                                             .and_yield(messages[1])
                                             .and_yield(messages[2])

      expect(YahtzeeBot::MessageHandler).to receive(:handle).exactly(3).times

      bot.run
    end

    it 'saves game after processing message' do
      game = instance_double(Yahtzee::Game, chat_id: 123_456)
      bot.instance_variable_get(:@games)[123_456] = game

      allow(YahtzeeBot::MessageHandler).to receive(:handle)

      expect(persistence).to receive(:save_game).with(game)

      bot.run
    end

    it 'handles non-message updates gracefully' do
      callback_query = instance_double(Telegram::Bot::Types::CallbackQuery)
      allow(telegram_bot).to receive(:listen).and_yield(callback_query)

      expect(YahtzeeBot::MessageHandler).not_to receive(:handle)

      bot.run
    end
  end

  describe 'error handling' do
    let(:message) do
      instance_double(
        Telegram::Bot::Types::Message,
        chat: instance_double(Telegram::Bot::Types::Chat, id: 123_456),
        from: instance_double(Telegram::Bot::Types::User, first_name: 'Alice', id: 789),
        text: '/roll'
      )
    end

    before do
      allow(Telegram::Bot::Client).to receive(:run).and_yield(telegram_bot)
      allow(telegram_bot).to receive(:listen).and_yield(message)
      allow(telegram_bot).to receive(:api).and_return(api)
    end

    it 'handles Game::Error exceptions' do
      error = Yahtzee::Game::GameNotStartedError.new('Game is not in progress')
      allow(YahtzeeBot::MessageHandler).to receive(:handle).and_raise(error)

      expect(api).to receive(:send_message).with(
        chat_id: 123_456,
        text: '❌ Game is not in progress'
      )

      bot.run
    end

    it 'handles StandardError exceptions' do
      error = StandardError.new('Something went wrong')
      allow(YahtzeeBot::MessageHandler).to receive(:handle).and_raise(error)

      expect(api).to receive(:send_message).with(
        chat_id: 123_456,
        text: "❌ Произошла ошибка. Пожалуйста, попробуйте снова.\nSomething went wrong"
      )

      bot.run
    end

    it 'logs error backtrace' do
      error = StandardError.new('Test error')
      allow(YahtzeeBot::MessageHandler).to receive(:handle).and_raise(error)
      allow(api).to receive(:send_message)

      expect { bot.run }.to output(/Error: StandardError - Test error/).to_stdout
    end

    it 'continues processing after error' do
      messages = [message, message]
      allow(telegram_bot).to receive(:listen).and_yield(messages[0])
                                             .and_yield(messages[1])

      allow(YahtzeeBot::MessageHandler).to receive(:handle).and_raise(StandardError)
      allow(api).to receive(:send_message)

      expect(YahtzeeBot::MessageHandler).to receive(:handle).twice

      bot.run
    end
  end

  describe 'game state management' do
    let(:message) do
      instance_double(
        Telegram::Bot::Types::Message,
        chat: instance_double(Telegram::Bot::Types::Chat, id: 123_456),
        text: '/new'
      )
    end

    before do
      allow(Telegram::Bot::Client).to receive(:run).and_yield(telegram_bot)
      allow(telegram_bot).to receive(:listen).and_yield(message)
      allow(telegram_bot).to receive(:api).and_return(api)
      allow(api).to receive(:send_message)
    end

    it 'maintains separate games for different chats' do
      chat1_message = message
      chat2_message = instance_double(
        Telegram::Bot::Types::Message,
        chat: instance_double(Telegram::Bot::Types::Chat, id: 789_012),
        text: '/new'
      )

      allow(telegram_bot).to receive(:listen).and_yield(chat1_message)
                                             .and_yield(chat2_message)

      expect(persistence).to receive(:load_game).with(123_456)
      expect(persistence).to receive(:load_game).with(789_012)

      bot.run
    end

    it 'cleans up finished games' do
      game = instance_double(Yahtzee::Game, state: :finished, chat_id: 123_456)
      bot.instance_variable_get(:@games)[123_456] = game

      allow(YahtzeeBot::MessageHandler).to receive(:handle)
      allow(game).to receive(:finish)

      expect(persistence).to receive(:delete_game).with(123_456)

      # Simulate /stop command
      allow(message).to receive(:text).and_return('/stop')
      bot.run
    end
  end
end
