# frozen_string_literal: true

require 'spec_helper'
require_relative '../../../lib/yahtzee_bot/bot'

RSpec.describe YahtzeeBot::Bot do
  let(:token) { 'test_token_12345' }
  let(:chat_id) { 123_456 }
  let(:message_id) { 42 }
  let(:callback_id) { 'cb_123' }

  let(:bot_api) { double('Telegram::Bot::Api') }
  let(:telegram_bot) { double('Telegram::Bot::Client', api: bot_api) }

  let(:bot_instance) { described_class.new }
  let(:persistence) { double('Yahtzee::Persistence') }
  let(:game) { double('Yahtzee::Game', chat_id:) }
  let(:real_game) { Yahtzee::Game.new(chat_id:) }

  before do
    allow(ENV).to receive(:fetch).with('TELEGRAM_BOT_TOKEN').and_return(token)
    allow(Yahtzee::Persistence).to receive(:new).and_return(persistence)
    allow(persistence).to receive(:load_game)
    allow(persistence).to receive(:save_game)

    allow(bot_api).to receive(:send_message)
    allow(bot_api).to receive(:answer_callback_query)
    allow(bot_api).to receive(:edit_message_text)
    allow(bot_api).to receive(:delete_webhook)

    allow(Telegram::Bot::Client).to receive(:run).and_yield(telegram_bot)
  end

  describe '#initialize' do
    it 'initializes with token from ENV' do
      expect(bot_instance.instance_variable_get(:@token)).to eq(token)
    end

    it 'creates persistence instance' do
      expect(bot_instance.instance_variable_get(:@persistence)).to eq(persistence)
    end

    it 'initializes empty games hash' do
      games = bot_instance.instance_variable_get(:@games)
      expect(games).to be_empty
    end
  end

  describe '#run' do
    it 'starts the bot and listens for updates' do
      allow(telegram_bot).to receive(:listen).and_return(nil)
      expect(Telegram::Bot::Client).to receive(:run).with(token)
      bot_instance.run
    end
  end

  describe '#handle_message' do
    let(:message) do
      double('Telegram::Bot::Types::Message',
             chat: double('Telegram::Bot::Types::Chat', id: chat_id),
             text: '/start')
    end

    before do
      allow(bot_instance).to receive(:load_game)
      allow(bot_instance).to receive(:save_game)
      allow(YahtzeeBot::MessageHandler).to receive(:handle).and_return(nil)
    end

    it 'loads game for chat' do
      expect(bot_instance).to receive(:load_game).with(chat_id)
      bot_instance.send(:handle_message, telegram_bot, message)
    end

    it 'calls MessageHandler.handle' do
      expect(YahtzeeBot::MessageHandler).to receive(:handle)
        .with(telegram_bot, message, nil, persistence)
      bot_instance.send(:handle_message, telegram_bot, message)
    end

    it 'does not save game when result is not a Game' do
      allow(YahtzeeBot::MessageHandler).to receive(:handle).and_return('some string')
      expect(bot_instance).not_to receive(:save_game)
      bot_instance.send(:handle_message, telegram_bot, message)
    end
  end

  describe '#handle_callback' do
    let(:callback) do
      double('Telegram::Bot::Types::CallbackQuery',
             data: 'roll',
             id: callback_id,
             message: double('Telegram::Bot::Types::Message',
                             chat: double('Telegram::Bot::Types::Chat', id: chat_id),
                             message_id:))
    end

    before do
      allow(bot_instance).to receive(:load_game)
      allow(bot_instance).to receive(:save_game)
    end

    it 'loads game for chat' do
      allow(YahtzeeBot::MessageHandler).to receive(:handle_callback).and_return(nil)
      expect(bot_instance).to receive(:load_game).with(chat_id)
      bot_instance.send(:handle_callback, telegram_bot, callback)
    end

    it 'calls MessageHandler.handle_callback' do
      allow(YahtzeeBot::MessageHandler).to receive(:handle_callback).and_return(nil)
      expect(YahtzeeBot::MessageHandler).to receive(:handle_callback)
        .with(telegram_bot, callback, nil, persistence)
      bot_instance.send(:handle_callback, telegram_bot, callback)
    end

    it 'saves game when result is a Game' do
      allow(YahtzeeBot::MessageHandler).to receive(:handle_callback).and_return(real_game)
      expect(bot_instance).to receive(:save_game).with(chat_id)
      bot_instance.send(:handle_callback, telegram_bot, callback)
    end

    it 'does not save game when result is not a Game' do
      allow(YahtzeeBot::MessageHandler).to receive(:handle_callback).and_return('not a game')
      expect(bot_instance).not_to receive(:save_game)
      bot_instance.send(:handle_callback, telegram_bot, callback)
    end

    it 'handles errors and answers with error message' do
      allow(YahtzeeBot::MessageHandler).to receive(:handle_callback).and_raise(StandardError, 'Test error')
      expect(bot_api).to receive(:answer_callback_query).with(
        callback_query_id: callback_id,
        text: 'Ошибка: Test error',
        show_alert: true
      )
      bot_instance.send(:handle_callback, telegram_bot, callback)
    end
  end

  describe '#load_game' do
    it 'does nothing if game already loaded' do
      games = { chat_id => game }
      bot_instance.instance_variable_set(:@games, games)
      expect(persistence).not_to receive(:load_game)
      bot_instance.send(:load_game, chat_id)
    end

    it 'loads game from persistence when not in memory' do
      allow(persistence).to receive(:load_game).with(chat_id).and_return(game)
      bot_instance.send(:load_game, chat_id)
      games = bot_instance.instance_variable_get(:@games)
      expect(games[chat_id]).to eq(game)
    end

    it 'does nothing when no saved game exists' do
      allow(persistence).to receive(:load_game).with(chat_id).and_return(nil)
      bot_instance.send(:load_game, chat_id)
      games = bot_instance.instance_variable_get(:@games)
      expect(games[chat_id]).to be_nil
    end
  end

  describe '#save_game' do
    it 'saves game to persistence' do
      games = { chat_id => game }
      bot_instance.instance_variable_set(:@games, games)
      expect(persistence).to receive(:save_game).with(game)
      bot_instance.send(:save_game, chat_id)
    end

    it 'does nothing when game not in memory' do
      expect(persistence).not_to receive(:save_game)
      bot_instance.send(:save_game, chat_id)
    end
  end
end
