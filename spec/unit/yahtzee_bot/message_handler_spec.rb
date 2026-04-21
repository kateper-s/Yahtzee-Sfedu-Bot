# frozen_string_literal: true

require 'spec_helper'
require_relative '../../../lib/yahtzee_bot/message_handler'
require_relative '../../../lib/yahtzee_bot/keyboard'

RSpec.describe YahtzeeBot::MessageHandler do
  let(:bot) { instance_double(Telegram::Bot::Client) }
  let(:api) { instance_double(Telegram::Bot::Api) }
  let(:message) do
    instance_double(
      Telegram::Bot::Types::Message,
      chat: instance_double(Telegram::Bot::Types::Chat, id: 123_456),
      from: instance_double(Telegram::Bot::Types::User, first_name: 'Alice', id: 789),
      text: command
    )
  end
  let(:game) { nil }
  let(:persistence) { instance_double(Yahtzee::Persistence) }
  let(:command) { '/start' }

  before do
    allow(bot).to receive(:api).and_return(api)
    allow(api).to receive(:send_message)
  end

  describe '.handle' do
    context 'with /start command' do
      let(:command) { '/start' }

      it 'sends welcome message' do
        expect(api).to receive(:send_message).with(
          chat_id: 123_456,
          text: /Добро пожаловать/
        )

        described_class.handle(bot, message, game, persistence)
      end
    end

    context 'with /new command' do
      let(:command) { '/new' }
      let(:game) { instance_double(Yahtzee::Game, state: :in_progress) }

      it 'creates new game' do
        expect(Yahtzee::Game).to receive(:new).with(chat_id: 123_456).and_call_original

        expect(api).to receive(:send_message).with(
          chat_id: 123_456,
          text: /Новая игра создана/,
          reply_markup: kind_of(Telegram::Bot::Types::ReplyKeyboardMarkup)
        )

        described_class.handle(bot, message, game, persistence)
      end

      it 'finishes existing game if present' do
        expect(game).to receive(:finish)

        described_class.handle(bot, message, game, persistence)
      end
    end

    context 'with /help command' do
      let(:command) { '/help' }

      it 'sends help message' do
        expect(api).to receive(:send_message).with(
          chat_id: 123_456,
          text: /Yahtzee - Помощь/
        )

        described_class.handle(bot, message, game, persistence)
      end

      it 'falls back to default help text when file missing' do
        allow(File).to receive(:read).and_raise(Errno::ENOENT)

        expect(api).to receive(:send_message).with(
          chat_id: 123_456,
          text: /Основные команды/
        )

        described_class.handle(bot, message, game, persistence)
      end
    end

    context 'with /rules command' do
      let(:command) { '/rules' }

      it 'sends rules message' do
        expect(api).to receive(:send_message).with(
          chat_id: 123_456,
          text: /Правила игры/
        )

        described_class.handle(bot, message, game, persistence)
      end
    end

    context 'with /categories command' do
      let(:command) { '/categories' }

      it 'sends categories list' do
        expect(api).to receive(:send_message).with(
          chat_id: 123_456,
          text: /Категории:/
        )

        described_class.handle(bot, message, game, persistence)
      end
    end

    context 'with /stats command' do
      let(:command) { '/stats' }

      it 'shows player statistics' do
        stats = {
          games_played: 10,
          average_score: 150.5,
          highest_score: 300,
          wins: 5
        }
        allow(persistence).to receive(:get_player_stats).with('Alice').and_return(stats)

        expect(api).to receive(:send_message).with(
          chat_id: 123_456,
          text: /Статистика игрока Alice.*Игр сыграно: 10/m
        )

        described_class.handle(bot, message, game, persistence)
      end
    end

    context 'with /leaderboard command' do
      let(:command) { '/leaderboard' }

      it 'shows leaderboard' do
        leaders = [
          { player_name: 'Alice', wins: 5, avg_score: 200.0 },
          { player_name: 'Bob', wins: 3, avg_score: 180.0 }
        ]
        allow(persistence).to receive(:get_leaderboard).with(10).and_return(leaders)

        expect(api).to receive(:send_message).with(
          chat_id: 123_456,
          text: /Таблица лидеров:.*Alice: 5 побед/m
        )

        described_class.handle(bot, message, game, persistence)
      end

      it 'handles empty leaderboard' do
        allow(persistence).to receive(:get_leaderboard).and_return([])

        expect(api).to receive(:send_message).with(
          chat_id: 123_456,
          text: /Пока нет данных/
        )

        described_class.handle(bot, message, game, persistence)
      end
    end

    context 'with /stop command' do
      let(:command) { '/stop' }
      let(:game) { instance_double(Yahtzee::Game) }

      it 'stops and deletes game' do
        expect(game).to receive(:finish)
        expect(persistence).to receive(:delete_game).with(123_456)

        expect(api).to receive(:send_message).with(
          chat_id: 123_456,
          text: /Игра завершена/
        )

        described_class.handle(bot, message, game, persistence)
      end
    end

    context 'with /join command' do
      let(:command) { '/join Alice' }
      let(:game) { instance_double(Yahtzee::Game, players: []) }

      context 'when game exists' do
        it 'adds player to game' do
          player = instance_double(Yahtzee::Player, name: 'Alice')
          expect(game).to receive(:add_player).with('Alice', 789).and_return(player)
          expect(game).to receive(:players).and_return([player])

          expect(api).to receive(:send_message).with(
            chat_id: 123_456,
            text: /Alice присоединился/,
            reply_markup: nil
          )

          described_class.handle(bot, message, game, persistence)
        end

        it 'shows start game keyboard when 2+ players' do
          player1 = instance_double(Yahtzee::Player, name: 'Alice')
          player2 = instance_double(Yahtzee::Player, name: 'Bob')
          expect(game).to receive(:add_player).and_return(player2)
          expect(game).to receive(:players).twice.and_return([player1, player2])

          expect(api).to receive(:send_message).with(
            chat_id: 123_456,
            text: /Bob присоединился/,
            reply_markup: kind_of(Telegram::Bot::Types::ReplyKeyboardMarkup)
          )

          described_class.handle(bot, message, game, persistence)
        end

        it 'handles duplicate player error' do
          expect(game).to receive(:add_player).and_raise(ArgumentError, 'Player already exists')

          expect(api).to receive(:send_message).with(
            chat_id: 123_456,
            text: '❌ Player already exists'
          )

          described_class.handle(bot, message, game, persistence)
        end
      end

      context 'when game does not exist' do
        let(:game) { nil }

        it 'prompts to create game first' do
          expect(api).to receive(:send_message).with(
            chat_id: 123_456,
            text: '❌ Сначала создайте игру с помощью /new'
          )

          described_class.handle(bot, message, game, persistence)
        end
      end
    end

    context 'with /start_game command' do
      let(:command) { '/start_game' }
      let(:game) { instance_double(Yahtzee::Game) }
      let(:player) { instance_double(Yahtzee::Player, name: 'Alice') }

      context 'when game exists' do
        it 'starts the game' do
          expect(game).to receive(:start)
          expect(game).to receive(:current_player).and_return(player)

          expect(api).to receive(:send_message).with(
            chat_id: 123_456,
            text: /Игра начинается.*Ход игрока: Alice/m,
            reply_markup: kind_of(Telegram::Bot::Types::ReplyKeyboardMarkup)
          )

          described_class.handle(bot, message, game, persistence)
        end

        it 'handles start errors' do
          expect(game).to receive(:start).and_raise(Yahtzee::Game::InvalidPlayerCountError)

          expect(api).to receive(:send_message).with(
            chat_id: 123_456,
            text: /❌/
          )

          described_class.handle(bot, message, game, persistence)
        end
      end

      context 'when game does not exist' do
        let(:game) { nil }

        it 'prompts to create game first' do
          expect(api).to receive(:send_message).with(
            chat_id: 123_456,
            text: '❌ Сначала создайте игру с помощью /new'
          )

          described_class.handle(bot, message, game, persistence)
        end
      end
    end

    context 'with /roll command' do
      let(:command) { '/roll' }
      let(:game) { instance_double(Yahtzee::Game, state: :in_progress) }
      let(:player) { instance_double(Yahtzee::Player, name: 'Alice') }
      let(:dice) { instance_double(Yahtzee::Dice, values: [1, 2, 3, 4, 5], rolls_left: 2) }

      before do
        allow(game).to receive(:current_player).and_return(player)
        allow(game).to receive(:dice).and_return(dice)
      end

      it 'rolls dice successfully' do
        expect(game).to receive(:roll_dice).and_return([1, 2, 3, 4, 5])
        expect(dice).to receive(:to_emojis).and_return('⚀ ⚁ ⚂ ⚃ ⚄')
        expect(dice).to receive(:can_roll?).and_return(true)

        expect(api).to receive(:send_message).with(
          chat_id: 123_456,
          text: /бросает кубики.*Осталось перебросов: 2/m,
          reply_markup: kind_of(Telegram::Bot::Types::ReplyKeyboardMarkup)
        )

        described_class.handle(bot, message, game, persistence)
      end

      it 'handles no rolls left' do
        expect(game).to receive(:roll_dice).and_return([1, 2, 3, 4, 5])
        expect(dice).to receive(:to_emojis).and_return('⚀ ⚁ ⚂ ⚃ ⚄')
        expect(dice).to receive(:can_roll?).and_return(false)

        expect(api).to receive(:send_message).with(
          chat_id: 123_456,
          text: /Перебросов не осталось/
        )

        described_class.handle(bot, message, game, persistence)
      end

      it 'validates game state' do
        allow(game).to receive(:state).and_return(:waiting_for_players)

        expect(api).to receive(:send_message).with(
          chat_id: 123_456,
          text: '❌ Игра ещё не началась!'
        )

        described_class.handle(bot, message, game, persistence)
      end
    end

    context 'with /reroll command' do
      let(:command) { '/reroll 1 3 5' }
      let(:game) { instance_double(Yahtzee::Game, state: :in_progress) }
      let(:player) { instance_double(Yahtzee::Player, name: 'Alice') }
      let(:dice) { instance_double(Yahtzee::Dice, values: [6, 2, 6, 4, 6], rolls_left: 1) }

      before do
        allow(game).to receive(:current_player).and_return(player)
        allow(game).to receive(:dice).and_return(dice)
        allow(dice).to receive(:rolled?).and_return(true)
      end

      it 'rerolls specified positions' do
        expect(game).to receive(:reroll_dice).with([1, 3, 5]).and_return([6, 2, 6, 4, 6])
        expect(dice).to receive(:to_emojis).and_return('⚅ ⚁ ⚅ ⚃ ⚅')
        expect(dice).to receive(:can_roll?).and_return(true)

        expect(api).to receive(:send_message).with(
          chat_id: 123_456,
          text: /перебрасывает кубики 1, 3, 5.*Осталось перебросов: 1/m,
          reply_markup: kind_of(Telegram::Bot::Types::ReplyKeyboardMarkup)
        )

        described_class.handle(bot, message, game, persistence)
      end

      it 'handles empty positions' do
        allow(message).to receive(:text).and_return('/reroll')

        expect(api).to receive(:send_message).with(
          chat_id: 123_456,
          text: '❌ Укажите позиции кубиков для переброса (от 1 до 5)'
        )

        described_class.handle(bot, message, game, persistence)
      end

      it 'validates dice were rolled' do
        allow(dice).to receive(:rolled?).and_return(false)

        expect(api).to receive(:send_message).with(
          chat_id: 123_456,
          text: '❌ Сначала бросьте кубики с помощью /roll'
        )

        described_class.handle(bot, message, game, persistence)
      end
    end

    context 'with /score command' do
      let(:command) { '/score 13' }
      let(:game) { instance_double(Yahtzee::Game, state: :in_progress) }
      let(:player) { instance_double(Yahtzee::Player, name: 'Alice') }
      let(:dice) { instance_double(Yahtzee::Dice) }

      before do
        allow(game).to receive(:current_player).and_return(player)
        allow(game).to receive(:dice).and_return(dice)
        allow(dice).to receive(:rolled?).and_return(true)
      end

      it 'selects category and records score' do
        expect(game).to receive(:select_category).with(13, 'Alice').and_return(25)
        expect(game).to receive(:game_over?).and_return(false)
        expect(game).to receive(:current_player).and_return(player)

        expect(api).to receive(:send_message).with(
          chat_id: 123_456,
          text: /выбрал категорию: Шанс.*Набрано очков: 25/m,
          reply_markup: kind_of(Telegram::Bot::Types::ReplyKeyboardMarkup)
        )

        described_class.handle(bot, message, game, persistence)
      end

      it 'handles game over' do
        expect(game).to receive(:select_category).with(13, 'Alice').and_return(25)
        expect(game).to receive(:game_over?).and_return(true)
        expect(game).to receive(:winner).and_return(player)
        expect(game).to receive(:finish)

        expect(api).to receive(:send_message).with(
          chat_id: 123_456,
          text: /Победитель: Alice/
        )

        described_class.handle(bot, message, game, persistence)
      end

      it 'handles tie game' do
        player2 = instance_double(Yahtzee::Player, name: 'Bob')
        expect(game).to receive(:select_category).with(13, 'Alice').and_return(25)
        expect(game).to receive(:game_over?).and_return(true)
        expect(game).to receive(:winner).and_return([player, player2])
        expect(game).to receive(:finish)

        expect(api).to receive(:send_message).with(
          chat_id: 123_456,
          text: /Ничья! Победители: Alice, Bob/
        )

        described_class.handle(bot, message, game, persistence)
      end

      it 'validates category number' do
        allow(message).to receive(:text).and_return('/score 14')

        expect(api).to receive(:send_message).with(
          chat_id: 123_456,
          text: '❌ Категория должна быть от 1 до 13'
        )

        described_class.handle(bot, message, game, persistence)
      end

      it 'handles category already used error' do
        expect(game).to receive(:select_category)
          .and_raise(ArgumentError, 'Category already used')

        expect(api).to receive(:send_message).with(
          chat_id: 123_456,
          text: '❌ Category already used'
        )

        described_class.handle(bot, message, game, persistence)
      end
    end

    context 'with /table command' do
      let(:command) { '/table' }
      let(:game) { instance_double(Yahtzee::Game, players: []) }

      it 'shows score table' do
        expect(api).to receive(:send_message).with(
          chat_id: 123_456,
          text: /```.*Категория.*```/m,
          parse_mode: 'MarkdownV2'
        )

        described_class.handle(bot, message, game, persistence)
      end

      it 'handles missing game' do
        expect(api).to receive(:send_message).with(
          chat_id: 123_456,
          text: '❌ Нет активной игры'
        )

        described_class.handle(bot, message, nil, persistence)
      end
    end

    context 'with /current command' do
      let(:command) { '/current' }
      let(:game) { instance_double(Yahtzee::Game) }

      context 'when waiting for players' do
        it 'shows waiting status' do
          allow(game).to receive(:state).and_return(:waiting_for_players)
          allow(game).to receive(:players).and_return([])

          expect(api).to receive(:send_message).with(
            chat_id: 123_456,
            text: /Ожидание игроков/
          )

          described_class.handle(bot, message, game, persistence)
        end
      end

      context 'when game in progress' do
        let(:player) { instance_double(Yahtzee::Player, name: 'Alice') }
        let(:dice) { instance_double(Yahtzee::Dice, values: [1, 2, 3, 4, 5], rolls_left: 2) }

        it 'shows current game state' do
          allow(game).to receive(:state).and_return(:in_progress)
          allow(game).to receive(:current_player).and_return(player)
          allow(game).to receive(:dice).and_return(dice)
          allow(dice).to receive(:rolled?).and_return(true)
          allow(dice).to receive(:to_emojis).and_return('⚀ ⚁ ⚂ ⚃ ⚄')

          expect(api).to receive(:send_message).with(
            chat_id: 123_456,
            text: /Идёт игра.*Ход: Alice.*Выпало: ⚀ ⚁ ⚂ ⚃ ⚄/m
          )

          described_class.handle(bot, message, game, persistence)
        end
      end
    end

    context 'with unknown command' do
      let(:command) { '/invalid' }

      it 'sends unknown command message' do
        expect(api).to receive(:send_message).with(
          chat_id: 123_456,
          text: /Неизвестная команда/
        )

        described_class.handle(bot, message, game, persistence)
      end
    end
  end

  describe 'private methods' do
    describe '#format_score_table' do
      let(:game) { instance_double(Yahtzee::Game) }
      let(:player1) { instance_double(Yahtzee::Player, name: 'Alice', scores: Array.new(17, 0)) }
      let(:player2) { instance_double(Yahtzee::Player, name: 'Bob', scores: Array.new(17, 0)) }

      it 'formats table with multiple players' do
        allow(game).to receive(:players).and_return([player1, player2])

        table = described_class.send(:format_score_table, game)

        expect(table).to include('Категория')
        expect(table).to include('Alice')
        expect(table).to include('Bob')
        expect(table).to include('ИТОГО')
      end
    end

    describe '#valid_game_state?' do
      let(:game) { instance_double(Yahtzee::Game) }

      it 'returns false when game is nil' do
        expect(api).to receive(:send_message).with(
          chat_id: 123_456,
          text: '❌ Сначала создайте игру с помощью /new'
        )

        result = described_class.send(:valid_game_state?, bot, 123_456, nil)
        expect(result).to be false
      end

      it 'returns false when game not in progress' do
        allow(game).to receive(:state).and_return(:waiting_for_players)

        expect(api).to receive(:send_message).with(
          chat_id: 123_456,
          text: '❌ Игра ещё не началась!'
        )

        result = described_class.send(:valid_game_state?, bot, 123_456, game)
        expect(result).to be false
      end

      it 'returns true for valid game state' do
        allow(game).to receive(:state).and_return(:in_progress)

        result = described_class.send(:valid_game_state?, bot, 123_456, game)
        expect(result).to be true
      end

      it 'checks dice when required' do
        allow(game).to receive(:state).and_return(:in_progress)
        dice = instance_double(Yahtzee::Dice)
        allow(game).to receive(:dice).and_return(dice)
        allow(dice).to receive(:rolled?).and_return(false)

        expect(api).to receive(:send_message).with(
          chat_id: 123_456,
          text: '❌ Сначала бросьте кубики с помощью /roll'
        )

        result = described_class.send(:valid_game_state?, bot, 123_456, game, check_dice: true)
        expect(result).to be false
      end
    end
  end
end
