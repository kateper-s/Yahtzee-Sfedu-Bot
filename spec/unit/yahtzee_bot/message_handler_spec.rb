# frozen_string_literal: true

require 'spec_helper'
require_relative '../../../lib/yahtzee_bot/message_handler'

RSpec.describe YahtzeeBot::MessageHandler do
  let(:bot) { instance_double(Telegram::Bot::Client) }
  let(:api) { instance_double(Telegram::Bot::Api) }
  let(:persistence) { instance_double(Yahtzee::Persistence) }
  let(:chat_id) { 123_456 }
  let(:message_id) { 42 }
  let(:callback_id) { 'callback_123' }

  let(:callback) do
    instance_double(
      Telegram::Bot::Types::CallbackQuery,
      data: callback_data,
      from: instance_double(Telegram::Bot::Types::User, id: 789, username: 'alice', first_name: 'Alice'),
      message: instance_double(
        Telegram::Bot::Types::Message,
        chat: instance_double(Telegram::Bot::Types::Chat, id: chat_id),
        message_id: message_id
      ),
      id: callback_id
    )
  end

  let(:message) do
    instance_double(
      Telegram::Bot::Types::Message,
      text: command,
      chat: instance_double(Telegram::Bot::Types::Chat, id: chat_id),
      from: instance_double(Telegram::Bot::Types::User, first_name: 'Alice', id: 789)
    )
  end

  let(:game) { nil }
  let(:command) { '/start' }
  let(:callback_data) { 'main_menu' }

  before do
    allow(bot).to receive(:api).and_return(api)
    allow(api).to receive(:send_message)
    allow(api).to receive(:edit_message_text)
    allow(api).to receive(:answer_callback_query)
  end

  describe '.handle' do
    context 'with /start' do
      let(:command) { '/start' }
      it 'sends welcome' do
        expect(api).to receive(:send_message).with(chat_id: chat_id, text: /Добро пожаловать/, reply_markup: anything)
        described_class.handle(bot, message, game, persistence)
      end
    end

    context 'with /new' do
      let(:command) { '/new' }
      it 'creates game' do
        expect(Yahtzee::Game).to receive(:new).and_call_original
        described_class.handle(bot, message, game, persistence)
      end
    end

    context 'with /help' do
      let(:command) { '/help' }
      it 'sends help' do
        expect(api).to receive(:send_message).with(chat_id: chat_id, text: /Помощь/, parse_mode: 'Markdown', reply_markup: anything)
        described_class.handle(bot, message, game, persistence)
      end
    end

    context 'with /rules' do
      let(:command) { '/rules' }
      it 'sends rules' do
        expect(api).to receive(:send_message).with(chat_id: chat_id, text: /Правила/, parse_mode: 'Markdown', reply_markup: anything)
        described_class.handle(bot, message, game, persistence)
      end
    end

    context 'with /stop' do
      let(:command) { '/stop' }
      let(:game) { instance_double(Yahtzee::Game, players: [], finish: nil) }
      it 'stops game' do
        expect(persistence).to receive(:delete_game)
        described_class.handle(bot, message, game, persistence)
      end
    end

    context 'with /menu' do
      let(:command) { '/menu' }
      it 'shows menu' do
        expect(api).to receive(:send_message).with(chat_id: chat_id, text: /Главное меню/, parse_mode: 'Markdown', reply_markup: anything)
        described_class.handle(bot, message, game, persistence)
      end
    end
  end

  describe '.handle_callback' do
    context 'new_game' do
      let(:callback_data) { 'new_game' }
      it 'creates new game' do
        expect(Yahtzee::Game).to receive(:new).and_call_original
        expect(api).to receive(:edit_message_text)
        described_class.handle_callback(bot, callback, game, persistence)
      end
    end

    context 'join_game' do
      let(:callback_data) { 'join_game' }
      let(:game) { instance_double(Yahtzee::Game, players: []) }
      it 'prompts for name' do
        expect(api).to receive(:send_message)
        described_class.handle_callback(bot, callback, game, persistence)
      end
    end

    context 'join_name_Игрок' do
      let(:callback_data) { 'join_name_Игрок' }
      let(:game) { instance_double(Yahtzee::Game) }
      before { allow(game).to receive(:add_player).and_return(double(name: 'Игрок')) }
      it 'adds player' do
        expect(game).to receive(:add_player).with('Игрок', 789)
        described_class.handle_callback(bot, callback, game, persistence)
      end
    end

    context 'start_game' do
      let(:callback_data) { 'start_game' }
      let(:game) { instance_double(Yahtzee::Game, state: :waiting_for_players, players: [double, double]) }
      before { allow(Yahtzee::Game).to receive(:const_get).with(:MIN_PLAYERS).and_return(2) }
      it 'starts game' do
        expect(game).to receive(:start)
        described_class.handle_callback(bot, callback, game, persistence)
      end
    end

    context 'roll' do
      let(:callback_data) { 'roll' }
      let(:game) { instance_double(Yahtzee::Game, state: :in_progress, dice: double(rolls_left: 2, to_emojis: '⚀')) }
      before { allow(game).to receive(:current_player).and_return(double(name: 'A')) }
      it 'rolls dice' do
        expect(game).to receive(:roll_dice)
        described_class.handle_callback(bot, callback, game, persistence)
      end
    end

    context 'reroll_start' do
      let(:callback_data) { 'reroll_start' }
      let(:game) { instance_double(Yahtzee::Game, state: :in_progress, dice: double(rolled?: true, values: [1,2,3,4,5], rolls_left: 1, to_emojis: '⚀')) }
      before { allow(game).to receive(:current_player).and_return(double(name: 'A')) }
      it 'shows reroll selection' do
        expect(api).to receive(:edit_message_text).with(anything, anything, text: /Выберите кубики/)
        described_class.handle_callback(bot, callback, game, persistence)
      end
    end

    context 'score_13' do
      let(:callback_data) { 'score_13' }
      let(:game) { instance_double(Yahtzee::Game, state: :in_progress, dice: double(rolled?: true)) }
      before do
        allow(game).to receive(:current_player).and_return(double(name: 'A'))
        allow(game).to receive(:select_category).and_return(25)
        allow(game).to receive(:game_over?).and_return(false)
        allow(game).to receive(:current_player).and_return(double(name: 'B'))
      end
      it 'selects category' do
        expect(game).to receive(:select_category).with(13, 'A')
        described_class.handle_callback(bot, callback, game, persistence)
      end
    end

    context 'table' do
      let(:callback_data) { 'table' }
      let(:game) { instance_double(Yahtzee::Game, players: [double(name: 'A', scores: Array.new(17, 0))]) }
      it 'shows table' do
        expect(api).to receive(:edit_message_text)
        expect(api).to receive(:send_message).at_least(2).times
        described_class.handle_callback(bot, callback, game, persistence)
      end
    end

    context 'categories' do
      let(:callback_data) { 'categories' }
      let(:game) { instance_double(Yahtzee::Game, state: :in_progress, dice: double(rolled?: true, values: [1,2,3,4,5])) }
      let(:player) { double(name: 'A', available_categories: [1,2,3]) }
      before do
        allow(game).to receive(:current_player).and_return(player)
        allow(Yahtzee::ScoreCalculator).to receive(:calculate).and_return(10)
      end
      it 'shows categories' do
        expect(api).to receive(:edit_message_text).with(anything, anything, text: /Доступные категории/)
        described_class.handle_callback(bot, callback, game, persistence)
      end
    end

    context 'current' do
      let(:callback_data) { 'current' }
      let(:game) { instance_double(Yahtzee::Game, state: :in_progress, dice: double(rolled?: true, to_emojis: '⚀', rolls_left: 2)) }
      let(:player) { double(name: 'A', used_categories: [], total_score: 150) }
      before { allow(game).to receive(:current_player).and_return(player) }
      it 'shows current state' do
        expect(api).to receive(:edit_message_text).with(anything, anything, text: /Информация о текущем ходе/)
        described_class.handle_callback(bot, callback, game, persistence)
      end
    end

    context 'stats' do
      let(:callback_data) { 'stats' }
      it 'shows stats' do
        expect(persistence).to receive(:get_player_stats).and_return(games_played: 5, wins: 2, average_score: 100, highest_score: 200)
        expect(api).to receive(:edit_message_text).with(anything, anything, text: /Ваша статистика/)
        described_class.handle_callback(bot, callback, game, persistence)
      end
    end

    context 'leaderboard' do
      let(:callback_data) { 'leaderboard' }
      it 'shows leaderboard' do
        expect(persistence).to receive(:get_leaderboard).and_return([{ player_name: 'A', wins: 5, avg_score: 150 }])
        expect(api).to receive(:edit_message_text).with(anything, anything, text: /Таблица лидеров/)
        described_class.handle_callback(bot, callback, game, persistence)
      end
    end

    context 'stop_game' do
      let(:callback_data) { 'stop_game' }
      let(:game) { instance_double(Yahtzee::Game, players: [], finish: nil) }
      it 'stops game' do
        expect(persistence).to receive(:delete_game)
        described_class.handle_callback(bot, callback, game, persistence)
      end
    end

    context 'main_menu' do
      let(:callback_data) { 'main_menu' }
      it 'shows main menu' do
        expect(api).to receive(:send_message).with(chat_id: chat_id, text: /Главное меню/)
        described_class.handle_callback(bot, callback, game, persistence)
      end
    end

    context 'rules' do
      let(:callback_data) { 'rules' }
      it 'sends rules' do
        expect(api).to receive(:edit_message_text).with(anything, anything, text: /Правила игры Yahtzee/)
        described_class.handle_callback(bot, callback, game, persistence)
      end
    end

    context 'help' do
      let(:callback_data) { 'help' }
      it 'sends help' do
        expect(api).to receive(:edit_message_text).with(anything, anything, text: /Помощь по игре Yahtzee/, anything)
        described_class.handle_callback(bot, callback, game, persistence)
      end
    end

    context 'error handling' do
      let(:callback_data) { 'invalid' }
      it 'handles errors' do
        expect(api).to receive(:answer_callback_query).with(callback_query_id: callback_id, text: /Ошибка/, show_alert: true)
        described_class.handle_callback(bot, callback, game, persistence)
      end
    end
  end
end