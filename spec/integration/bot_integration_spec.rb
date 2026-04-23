# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'YahtzeeBot Integration' do
  let(:chat_id) { 123_456 }
  let(:message_id) { 42 }
  let(:callback_id) { 'cb_123' }
  let(:token) { 'test_token_12345' }

  # Используем двойников вместо реальных классов
  let(:api) { double('Telegram::Bot::Api') }
  let(:bot) { double('Telegram::Bot::Client', api:) }

  let(:persistence) { double('Yahtzee::Persistence') }

  before do
    # Мокаем ENV.fetch для токена
    allow(ENV).to receive(:fetch).with('TELEGRAM_BOT_TOKEN').and_return(token)

    # Настраиваем моки для API
    allow(api).to receive(:send_message)
    allow(api).to receive(:answer_callback_query)
    allow(api).to receive(:edit_message_text)
    allow(api).to receive(:delete_webhook)

    # Настраиваем мок для Telegram::Bot::Client.run
    allow(Telegram::Bot::Client).to receive(:run).and_yield(bot)

    # Настраиваем мок для persistence
    allow(persistence).to receive(:save_game)
    allow(persistence).to receive(:load_game)
    allow(persistence).to receive(:delete_game)
    allow(persistence).to receive(:get_player_stats).and_return(
      games_played: 0, wins: 0, average_score: 0, highest_score: 0
    )
    allow(persistence).to receive(:get_leaderboard).and_return([])

    # Мокаем Yahtzee::Persistence.new
    allow(Yahtzee::Persistence).to receive(:new).and_return(persistence)
  end

  describe 'game flow' do
    it 'handles complete game session' do
      # Создаем бота
      bot_instance = YahtzeeBot::Bot.new

      # Создаем сообщение для /start
      start_message = double('Telegram::Bot::Types::Message',
                             text: '/start',
                             chat: double('Telegram::Bot::Types::Chat', id: chat_id),
                             from: double('Telegram::Bot::Types::User', id: 789, first_name: 'Alice'))

      # Обрабатываем /start
      expect(api).to receive(:send_message).at_least(:once)
      bot_instance.send(:handle_message, bot, start_message)

      # Создаем callback для новой игры
      new_game_callback = double('Telegram::Bot::Types::CallbackQuery',
                                 data: 'new_game',
                                 from: double('Telegram::Bot::Types::User', id: 789, username: 'alice'),
                                 message: double('Telegram::Bot::Types::Message',
                                                 chat: double('Telegram::Bot::Types::Chat', id: chat_id),
                                                 message_id:),
                                 id: callback_id)

      # Обрабатываем создание новой игры
      expect(api).to receive(:edit_message_text).at_least(:once)
      bot_instance.send(:handle_callback, bot, new_game_callback)
    end
  end

  describe 'error handling' do
    it 'handles invalid commands gracefully' do
      bot_instance = YahtzeeBot::Bot.new

      unknown_message = double('Telegram::Bot::Types::Message',
                               text: '/unknown_command',
                               chat: double('Telegram::Bot::Types::Chat', id: chat_id),
                               from: double('Telegram::Bot::Types::User', id: 789, first_name: 'Alice'))

      bot_instance.send(:handle_message, bot, unknown_message)
      expect { bot_instance.send(:handle_message, bot, unknown_message) }.not_to raise_error
    end

    it 'prevents actions when game not started' do
      bot_instance = YahtzeeBot::Bot.new

      # Создаем callback для броска кубиков без активной игры
      roll_callback = double('Telegram::Bot::Types::CallbackQuery',
                             data: 'roll',
                             from: double('Telegram::Bot::Types::User', id: 789, username: 'alice'),
                             message: double('Telegram::Bot::Types::Message',
                                             chat: double('Telegram::Bot::Types::Chat', id: chat_id),
                                             message_id:),
                             id: callback_id)

      expect(api).to receive(:answer_callback_query).with(
        callback_query_id: callback_id,
        text: /Сначала создайте игру через меню/,
        show_alert: true
      )

      bot_instance.send(:handle_callback, bot, roll_callback)
    end
  end
end
