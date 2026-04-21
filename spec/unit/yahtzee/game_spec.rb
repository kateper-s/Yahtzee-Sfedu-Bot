# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Yahtzee::Game do
  let(:chat_id) { 123_456 }
  let(:game) { described_class.new(chat_id: chat_id) }

  describe '#initialize' do
    it 'creates a new game with waiting_for_players state' do
      expect(game.state).to eq(:waiting_for_players)
      expect(game.players).to be_empty
      expect(game.chat_id).to eq(chat_id)
      expect(game.dice).to be_a(Yahtzee::Dice)
    end
  end

  describe '#add_player' do
    context 'when game is waiting for players' do
      it 'adds a player successfully' do
        player = game.add_player('Alice')
        expect(player).to be_a(Yahtzee::Player)
        expect(player.name).to eq('Alice')
        expect(game.players.size).to eq(1)
      end

      it 'raises error when adding duplicate player' do
        game.add_player('Alice')
        expect { game.add_player('Alice') }.to raise_error(ArgumentError, /already exists/)
      end

      it 'raises error when maximum players reached' do
        4.times { |i| game.add_player("Player#{i}") }
        expect { game.add_player('Extra') }.to raise_error(Yahtzee::Game::InvalidPlayerCountError)
      end
    end

    context 'when game has started' do
      before do
        game.add_player('Alice')
        game.start
      end

      it 'raises error' do
        expect { game.add_player('Bob') }.to raise_error(Yahtzee::Game::GameAlreadyStartedError)
      end
    end
  end

  describe '#start' do
    context 'with valid number of players' do
      before { game.add_player('Alice') }

      it 'starts the game' do
        expect(game.start).to be true
        expect(game.state).to eq(:in_progress)
        expect(game.current_player.name).to eq('Alice')
      end
    end

    context 'with no players' do
      it 'raises error' do
        expect { game.start }.to raise_error(Yahtzee::Game::InvalidPlayerCountError)
      end
    end
  end

  describe '#roll_dice' do
    before do
      game.add_player('Alice')
      game.start
    end

    it 'rolls dice successfully' do
      dice_values = game.roll_dice
      expect(dice_values.size).to eq(5)
      expect(dice_values).to all(be_between(1, 6))
      expect(game.dice.rolls_left).to eq(2)
    end

    it 'raises error when no rolls left' do
      3.times { game.roll_dice }
      expect { game.roll_dice }.to raise_error(Yahtzee::Dice::NoRollsLeftError)
    end
  end

  describe '#select_category' do
    before do
      game.add_player('Alice')
      game.start
      game.roll_dice
    end

    it 'records score and moves to next player' do
      points = game.select_category(13, 'Alice')
      expect(points).to be >= 5
      expect(game.current_player).to eq(game.players[0])
      expect(game.dice.rolled?).to be false
    end

    it 'raises error for invalid player turn' do
      game.add_player('Bob')
      expect { game.select_category(1, 'Bob') }.to raise_error(Yahtzee::Game::NotPlayersTurnError)
    end

    it 'raises error when category already used' do
      game.select_category(1, 'Alice')
      game.roll_dice
      expect { game.select_category(1, 'Alice') }.to raise_error(ArgumentError, /already used/)
    end
  end

  describe '#game_over?' do
    before do
      game.add_player('Alice')
      game.start
    end

    it 'returns true when all categories used' do
      allow(game.players.first).to receive(:all_categories_used?).and_return(true)
      expect(game.game_over?).to be true
    end

    it 'returns false when categories remain' do
      allow(game.players.first).to receive(:all_categories_used?).and_return(false)
      expect(game.game_over?).to be false
    end
  end
end