# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Yahtzee::Player do
  let(:player) { described_class.new(name: 'Alice') }

  describe '#initialize' do
    it 'creates player with name' do
      expect(player.name).to eq('Alice')
    end

    it 'creates player with id' do
      player_with_id = described_class.new(name: 'Bob', id: 42)
      expect(player_with_id.id).to eq(42)
    end

    it 'initializes scores array with 17 zeros' do
      expect(player.scores).to eq(Array.new(17, 0))
    end

    it 'initializes empty used_categories' do
      expect(player.used_categories).to be_empty
    end

    it 'initializes total_score to 0' do
      expect(player.total_score).to eq(0)
    end
  end

  describe '#add_score' do
    context 'with numbers categories (1-6)' do
      it 'adds score for ones' do
        player.add_score(1, 3)
        expect(player.scores[0]).to eq(3)
      end

      it 'adds score for twos' do
        player.add_score(2, 4)
        expect(player.scores[1]).to eq(4)
      end

      it 'adds score for sixes' do
        player.add_score(6, 12)
        expect(player.scores[5]).to eq(12)
      end
    end

    context 'with lower section categories (7-13)' do
      it 'adds score for three of a kind' do
        player.add_score(7, 15)
        expect(player.scores[8]).to eq(15)
      end

      it 'adds score for full house' do
        player.add_score(9, 25)
        expect(player.scores[10]).to eq(25)
      end

      it 'adds score for yahtzee' do
        player.add_score(12, 50)
        expect(player.scores[13]).to eq(50)
      end

      it 'adds score for chance' do
        player.add_score(13, 20)
        expect(player.scores[14]).to eq(20)
      end
    end

    context 'when updating totals' do
      it 'updates upper section total' do
        player.add_score(1, 3)
        player.add_score(2, 4)
        player.add_score(3, 5)
        expect(player.upper_section_total).to eq(12)
      end

      it 'updates lower section total' do
        player.add_score(13, 20)
        player.add_score(7, 15)
        expect(player.lower_section_total).to eq(35)
      end

      it 'adds bonus when upper section reaches 63' do
        player.add_score(1, 10)
        player.add_score(2, 10)
        player.add_score(3, 10)
        player.add_score(4, 10)
        player.add_score(5, 10)
        player.add_score(6, 13)
        expect(player.bonus).to eq(35)
      end

      it 'does not add bonus when upper section below 63' do
        player.add_score(1, 3)
        expect(player.bonus).to eq(0)
      end

      it 'updates total score correctly' do
        player.add_score(1, 3)
        player.add_score(2, 4)
        player.add_score(13, 20)
        expect(player.total_score).to eq(27)
      end

      it 'updates total score with bonus' do
        player.add_score(1, 10)
        player.add_score(2, 10)
        player.add_score(3, 10)
        player.add_score(4, 10)
        player.add_score(5, 10)
        player.add_score(6, 13)
        expect(player.total_score).to eq(63 + 35)
      end
    end

    context 'when error handling' do
      it 'raises error for category less than 1' do
        expect { player.add_score(0, 10) }.to raise_error(ArgumentError)
      end

      it 'raises error for category greater than 13' do
        expect { player.add_score(14, 10) }.to raise_error(ArgumentError)
      end
    end
  end

  describe '#category_used?' do
    it 'returns false for unused category' do
      expect(player.category_used?(1)).to be false
    end

    it 'returns true for used category' do
      player.add_score(1, 5)
      expect(player.category_used?(1)).to be true
    end

    it 'returns false for invalid category' do
      expect(player.category_used?(14)).to be false
    end
  end

  describe '#available_categories' do
    it 'returns all categories initially' do
      expect(player.available_categories).to eq((1..13).to_a)
    end

    it 'returns remaining categories after some used' do
      player.add_score(1, 5)
      player.add_score(2, 4)
      player.add_score(3, 3)
      expect(player.available_categories).to eq([4, 5, 6, 7, 8, 9, 10, 11, 12, 13])
    end

    it 'returns empty array when all categories used' do
      (1..13).each { |cat| player.add_score(cat, 0) }
      expect(player.available_categories).to be_empty
    end
  end

  describe '#all_categories_used?' do
    it 'returns false initially' do
      expect(player.all_categories_used?).to be false
    end

    it 'returns false when some categories remain' do
      player.add_score(1, 5)
      expect(player.all_categories_used?).to be false
    end

    it 'returns true when all 13 categories used' do
      (1..13).each { |cat| player.add_score(cat, 0) }
      expect(player.all_categories_used?).to be true
    end
  end

  describe '#upper_section_total' do
    it 'returns 0 initially' do
      expect(player.upper_section_total).to eq(0)
    end

    it 'returns sum of upper section scores' do
      player.add_score(1, 3)
      player.add_score(2, 4)
      player.add_score(3, 5)
      expect(player.upper_section_total).to eq(12)
    end
  end

  describe '#bonus' do
    it 'returns 0 initially' do
      expect(player.bonus).to eq(0)
    end

    it 'returns 0 when upper section < 63' do
      6.times { |i| player.add_score(i + 1, 10) }
      expect(player.bonus).to eq(0)
    end

    it 'returns 35 when upper section >= 63' do
      player.add_score(1, 10)
      player.add_score(2, 10)
      player.add_score(3, 10)
      player.add_score(4, 10)
      player.add_score(5, 10)
      player.add_score(6, 13)
      expect(player.bonus).to eq(35)
    end
  end

  describe '#lower_section_total' do
    it 'returns 0 initially' do
      expect(player.lower_section_total).to eq(0)
    end

    it 'returns sum of lower section scores' do
      player.add_score(13, 20)
      player.add_score(7, 15)
      expect(player.lower_section_total).to eq(35)
    end
  end

  describe '#to_h' do
    it 'returns hash representation of player' do
      player.add_score(1, 5)
      hash = player.to_h
      expect(hash[:name]).to eq('Alice')
      expect(hash[:scores][0]).to eq(5)
      expect(hash[:total_score]).to eq(5)
    end

    it 'includes id when present' do
      player_with_id = described_class.new(name: 'Bob', id: 42)
      hash = player_with_id.to_h
      expect(hash[:id]).to eq(42)
    end
  end

  describe '.from_h' do
    it 'creates player from hash' do
      data = {
        id: 42,
        name: 'Charlie',
        scores: [5, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5],
        used_categories: [1],
        total_score: 5
      }
      player = described_class.from_h(data)
      expect(player.id).to eq(42)
      expect(player.name).to eq('Charlie')
      expect(player.scores[0]).to eq(5)
    end

    it 'creates player without id' do
      data = {
        name: 'David',
        scores: Array.new(17, 0),
        used_categories: [],
        total_score: 0
      }
      player = described_class.from_h(data)
      expect(player.id).to be_nil
      expect(player.name).to eq('David')
    end
  end
end
