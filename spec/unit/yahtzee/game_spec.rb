# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Yahtzee::Game do
  let(:chat_id) { 123_456 }
  let(:game) { described_class.new(chat_id:) }

  describe '#initialize' do
    it 'creates a new game with waiting_for_players state' do
      expect(game.state).to eq(:waiting_for_players)
    end

    it 'has empty players list' do
      expect(game.players).to be_empty
    end

    it 'has no current player' do
      expect(game.current_player).to be_nil
    end

    it 'initializes dice' do
      expect(game.dice).to be_a(Yahtzee::Dice)
    end

    it 'sets chat_id' do
      expect(game.chat_id).to eq(chat_id)
    end
  end

  describe '#add_player' do
    it 'adds a player successfully' do
      player = game.add_player('Alice')
      expect(game.players.size).to eq(1)
      expect(player.name).to eq('Alice')
    end

    it 'adds player with custom id' do
      player = game.add_player('Bob', 42)
      expect(player.id).to eq(42)
    end

    it 'raises error when adding duplicate player' do
      game.add_player('Alice')
      expect { game.add_player('Alice') }.to raise_error(ArgumentError)
    end

    it 'raises error when game already started' do
      game.add_player('Alice')
      game.start
      expect { game.add_player('Bob') }.to raise_error(Yahtzee::Game::GameAlreadyStartedError)
    end

    it 'raises error when max players reached' do
      4.times { |i| game.add_player("Player#{i}") }
      expect { game.add_player('Extra') }.to raise_error(Yahtzee::Game::InvalidPlayerCountError)
    end
  end

  describe '#remove_player' do
    before { game.add_player('Alice') }

    it 'removes player successfully' do
      game.remove_player('Alice')
      expect(game.players).to be_empty
    end

    it 'raises error when game already started' do
      game.add_player('Bob')
      game.start
      expect { game.remove_player('Bob') }.to raise_error(Yahtzee::Game::GameAlreadyStartedError)
    end

    it 'does nothing if player not found' do
      expect { game.remove_player('Unknown') }.not_to(change { game.players.count })
    end
  end

  describe '#start' do
    it 'starts game with valid number of players' do
      game.add_player('Alice')
      game.start
      expect(game.state).to eq(:in_progress)
      expect(game.current_player).not_to be_nil
    end

    it 'raises error with no players' do
      expect { game.start }.to raise_error(Yahtzee::Game::InvalidPlayerCountError)
    end

    it 'raises error when game already started' do
      game.add_player('Alice')
      game.start
      expect { game.start }.to raise_error(Yahtzee::Game::GameAlreadyStartedError)
    end

    it 'sets current player to first player' do
      game.add_player('Alice')
      game.add_player('Bob')
      game.start
      expect(game.current_player.name).to eq('Alice')
    end
  end

  describe '#roll_dice' do
    before do
      game.add_player('Alice')
      game.start
    end

    it 'rolls dice successfully' do
      values = game.roll_dice
      expect(values.size).to eq(5)
      expect(game.dice.rolled?).to be true
    end

    it 'raises error when game not in progress' do
      new_game = described_class.new(chat_id: 456)
      new_game.add_player('Bob')
      expect { new_game.roll_dice }.to raise_error(Yahtzee::Game::GameNotStartedError)
    end

    it 'raises error when no rolls left' do
      3.times { game.roll_dice }
      expect { game.roll_dice }.to raise_error(Yahtzee::Dice::NoRollsLeftError)
    end
  end

  describe '#reroll_dice' do
    before do
      game.add_player('Alice')
      game.start
      game.roll_dice
    end

    it 'raises error when dice not rolled' do
      game.instance_variable_get(:@dice).reset
      expect { game.reroll_dice([1]) }.to raise_error(Yahtzee::Game::DiceNotRolledError)
    end

    it 'raises error when no rolls left' do
      2.times { game.reroll_dice([1]) }
      expect { game.reroll_dice([1]) }.to raise_error(Yahtzee::Dice::NoRollsLeftError)
    end
  end

  describe '#select_category' do
    before do
      game.add_player('Alice')
      game.add_player('Bob')
      game.start
      game.roll_dice
    end

    it 'selects category and records score' do
      points = game.select_category(13, 'Alice')
      expect(points).to be_between(5, 30)
      expect(game.current_player.name).to eq('Bob')
    end

    it 'raises error for invalid player turn' do
      expect { game.select_category(13, 'Bob') }.to raise_error(Yahtzee::Game::NotPlayersTurnError)
    end

    it 'raises error when dice not rolled' do
      game.instance_variable_get(:@dice).reset
      expect { game.select_category(13, 'Alice') }.to raise_error(Yahtzee::Game::DiceNotRolledError)
    end
  end

  describe '#game_over?' do
    it 'returns false initially' do
      game.add_player('Alice')
      expect(game.game_over?).to be false
    end

    it 'returns true when all categories used' do
      game.add_player('Alice')
      game.start
      (1..13).each do |category|
        game.roll_dice
        game.select_category(category, 'Alice')
      end
      expect(game.game_over?).to be true
    end
  end

  describe '#winner' do
    it 'returns player with highest score' do
      game = described_class.new(chat_id: 123)
      alice = game.add_player('Alice', 1)
      bob   = game.add_player('Bob', 2)
      game.start

      allow(alice).to receive(:total_score).and_return(200)
      allow(bob).to receive(:total_score).and_return(150)
      allow(game).to receive(:game_over?).and_return(true)

      expect(game.winner).to eq(alice)
    end
  end

  describe '#finish' do
    it 'sets state to finished' do
      game.finish
      expect(game.state).to eq(:finished)
    end
  end

  describe '#to_h' do
    it 'returns hash representation' do
      game.add_player('Alice')
      hash = game.to_h
      expect(hash[:chat_id]).to eq(chat_id)
      expect(hash[:players].size).to eq(1)
      expect(hash[:state]).to eq('waiting_for_players')
    end
  end

  describe '.from_h' do
    it 'creates game from hash' do
      data = {
        id: 1,
        chat_id: 123,
        players: [{ name: 'Alice', scores: Array.new(17, 0), used_categories: [], total_score: 0 }],
        current_player_index: 0,
        state: 'in_progress',
        created_at: Time.now.to_s,
        updated_at: Time.now.to_s
      }
      restored = described_class.from_h(data)
      expect(restored.chat_id).to eq(123)
      expect(restored.players.size).to eq(1)
      expect(restored.players.first.name).to eq('Alice')
    end
  end
end
