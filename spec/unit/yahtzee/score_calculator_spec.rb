# frozen_string_literal: true

require 'spec_helper'
require_relative '../../../lib/yahtzee/score_calculator'

RSpec.describe Yahtzee::ScoreCalculator do
  describe '.calculate' do
    context 'with numbers categories (1-6)' do
      it 'calculates ones' do
        expect(described_class.calculate(1, [1, 1, 2, 3, 4])).to eq(2)
      end

      it 'calculates twos' do
        expect(described_class.calculate(2, [2, 2, 2, 3, 4])).to eq(6)
      end

      it 'calculates threes' do
        expect(described_class.calculate(3, [3, 3, 1, 2, 5])).to eq(6)
      end

      it 'calculates fours' do
        expect(described_class.calculate(4, [4, 4, 4, 1, 2])).to eq(12)
      end

      it 'calculates fives' do
        expect(described_class.calculate(5, [5, 5, 1, 2, 3])).to eq(10)
      end

      it 'calculates sixes' do
        expect(described_class.calculate(6, [6, 6, 6, 6, 1])).to eq(24)
      end

      it 'returns 0 when no matching numbers' do
        expect(described_class.calculate(1, [2, 3, 4, 5, 6])).to eq(0)
      end
    end

    context 'with three of a kind (7)' do
      it 'returns sum when three of a kind present' do
        expect(described_class.calculate(7, [3, 3, 3, 4, 5])).to eq(18)
      end

      it 'returns 0 when no three of a kind' do
        expect(described_class.calculate(7, [1, 2, 3, 4, 5])).to eq(0)
      end

      it 'works with four of a kind' do
        expect(described_class.calculate(7, [4, 4, 4, 4, 5])).to eq(21)
      end
    end

    context 'with four of a kind (8)' do
      it 'returns sum when four of a kind present' do
        expect(described_class.calculate(8, [4, 4, 4, 4, 5])).to eq(21)
      end

      it 'returns 0 when no four of a kind' do
        expect(described_class.calculate(8, [1, 2, 3, 4, 5])).to eq(0)
      end
    end

    context 'with full house (9)' do
      it 'returns 25 for valid full house' do
        expect(described_class.calculate(9, [2, 2, 2, 5, 5])).to eq(25)
      end

      it 'returns 0 for invalid full house' do
        expect(described_class.calculate(9, [1, 2, 3, 4, 5])).to eq(0)
      end

      it 'returns 0 for four of a kind' do
        expect(described_class.calculate(9, [3, 3, 3, 3, 4])).to eq(0)
      end
    end

    context 'with small straight (10)' do
      it 'returns 30 for valid small straight' do
        expect(described_class.calculate(10, [1, 2, 3, 4, 6])).to eq(30)
      end

      it 'returns 30 for another valid small straight' do
        expect(described_class.calculate(10, [2, 3, 4, 5, 6])).to eq(30)
      end

      it 'returns 0 for invalid small straight' do
        expect(described_class.calculate(10, [1, 2, 3, 5, 6])).to eq(0)
      end
    end

    context 'with large straight (11)' do
      it 'returns 40 for valid large straight' do
        expect(described_class.calculate(11, [1, 2, 3, 4, 5])).to eq(40)
      end

      it 'returns 40 for another valid large straight' do
        expect(described_class.calculate(11, [2, 3, 4, 5, 6])).to eq(40)
      end

      it 'returns 0 for invalid large straight' do
        expect(described_class.calculate(11, [1, 2, 3, 4, 6])).to eq(0)
      end
    end

    context 'with yahtzee (12)' do
      it 'returns 50 for five of a kind' do
        expect(described_class.calculate(12, [5, 5, 5, 5, 5])).to eq(50)
      end

      it 'returns 0 for not five of a kind' do
        expect(described_class.calculate(12, [1, 2, 3, 4, 5])).to eq(0)
      end
    end

    context 'with chance (13)' do
      it 'returns sum of all dice' do
        expect(described_class.calculate(13, [1, 2, 3, 4, 5])).to eq(15)
      end
    end

    context 'with invalid category' do
      it 'returns 0' do
        expect(described_class.calculate(99, [1, 2, 3, 4, 5])).to eq(0)
      end
    end
  end

  describe '.calculate_upper_section_total' do
    it 'returns 0 for empty scores' do
      scores = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
      expect(described_class.calculate_upper_section_total(scores)).to eq(0)
    end

    it 'sums first 6 scores' do
      scores = [1, 2, 3, 4, 5, 6, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
      expect(described_class.calculate_upper_section_total(scores)).to eq(21)
    end
  end

  describe '.calculate_bonus' do
    it 'returns 35 when upper_total >= 63' do
      expect(described_class.calculate_bonus(63)).to eq(35)
      expect(described_class.calculate_bonus(70)).to eq(35)
    end

    it 'returns 0 when upper_total < 63' do
      expect(described_class.calculate_bonus(62)).to eq(0)
      expect(described_class.calculate_bonus(0)).to eq(0)
    end
  end

  describe '.calculate_lower_section_total' do
    it 'returns 0 for empty scores' do
      scores = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
      expect(described_class.calculate_lower_section_total(scores)).to eq(0)
    end

    it 'sums indices 8 through 14' do
      scores = Array.new(17, 0)
      (8..14).each { |i| scores[i] = i }
      expected = 8 + 9 + 10 + 11 + 12 + 13 + 14
      expect(described_class.calculate_lower_section_total(scores)).to eq(expected)
    end
  end

  describe '.calculate_total_score' do
    it 'calculates total without bonus' do
      scores = [1, 2, 3, 4, 5, 6, 0, 0, 1, 2, 3, 4, 5, 6, 7, 0, 0]
      upper = 1 + 2 + 3 + 4 + 5 + 6
      lower = 1 + 2 + 3 + 4 + 5 + 6 + 7
      expect(described_class.calculate_total_score(scores)).to eq(upper + lower)
    end

    it 'calculates total with bonus' do
      scores = [10, 10, 10, 10, 10, 13, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
      expect(described_class.calculate_total_score(scores)).to eq(63 + 35)
    end

    it 'calculates total with all sections filled' do
      scores = [10, 10, 10, 10, 10, 10, 60, 35, 15, 20, 25, 30, 40, 50, 20, 200, 0]
      expected = 60 + 200
      expect(described_class.calculate_total_score(scores)).to eq(expected)
    end
  end

  describe 'constants' do
    it 'has correct BONUS_THRESHOLD' do
      expect(described_class::BONUS_THRESHOLD).to eq(63)
    end

    it 'has correct BONUS_POINTS' do
      expect(described_class::BONUS_POINTS).to eq(35)
    end

    it 'has ones category' do
      expect(described_class::CATEGORIES[:ones]).to eq(1)
    end

    it 'has twos category' do
      expect(described_class::CATEGORIES[:twos]).to eq(2)
    end

    it 'has threes category' do
      expect(described_class::CATEGORIES[:threes]).to eq(3)
    end

    it 'has fours category' do
      expect(described_class::CATEGORIES[:fours]).to eq(4)
    end

    it 'has fives category' do
      expect(described_class::CATEGORIES[:fives]).to eq(5)
    end

    it 'has sixes category' do
      expect(described_class::CATEGORIES[:sixes]).to eq(6)
    end

    it 'has three of a kind category' do
      expect(described_class::CATEGORIES[:three_of_kind]).to eq(7)
    end

    it 'has four of a kind category' do
      expect(described_class::CATEGORIES[:four_of_kind]).to eq(8)
    end

    it 'has full house category' do
      expect(described_class::CATEGORIES[:full_house]).to eq(9)
    end

    it 'has small straight category' do
      expect(described_class::CATEGORIES[:small_straight]).to eq(10)
    end

    it 'has large straight category' do
      expect(described_class::CATEGORIES[:large_straight]).to eq(11)
    end

    it 'has yahtzee category' do
      expect(described_class::CATEGORIES[:yahtzee]).to eq(12)
    end

    it 'has chance category' do
      expect(described_class::CATEGORIES[:chance]).to eq(13)
    end
  end
end
