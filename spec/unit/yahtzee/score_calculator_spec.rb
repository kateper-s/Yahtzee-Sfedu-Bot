# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Yahtzee::ScoreCalculator do
  describe '.calculate' do
    context 'with numbers categories (1-6)' do
      it 'calculates sum of ones' do
        dice = [1, 1, 3, 4, 5]
        expect(described_class.calculate(1, dice)).to eq(2)
      end

      it 'calculates sum of sixes' do
        dice = [6, 6, 6, 4, 5]
        expect(described_class.calculate(6, dice)).to eq(18)
      end

      it 'returns 0 when no matching numbers' do
        dice = [2, 3, 4, 5, 6]
        expect(described_class.calculate(1, dice)).to eq(0)
      end
    end

    context 'with three of a kind' do
      it 'returns sum when three of a kind present' do
        dice = [3, 3, 3, 4, 5]
        expect(described_class.calculate(7, dice)).to eq(18)
      end

      it 'returns 0 when no three of a kind' do
        dice = [1, 2, 3, 4, 5]
        expect(described_class.calculate(7, dice)).to eq(0)
      end
    end

    context 'with full house' do
      it 'returns 25 for valid full house' do
        dice = [2, 2, 3, 3, 3]
        expect(described_class.calculate(9, dice)).to eq(25)
      end

      it 'returns 0 for invalid full house' do
        dice = [2, 2, 3, 3, 4]
        expect(described_class.calculate(9, dice)).to eq(0)
      end
    end

    context 'with small straight' do
      it 'returns 30 for valid small straight' do
        dice = [1, 2, 3, 4, 6]
        expect(described_class.calculate(10, dice)).to eq(30)
      end

      it 'returns 0 for invalid small straight' do
        dice = [1, 3, 4, 5, 6]
        expect(described_class.calculate(10, dice)).to eq(0)
      end
    end

    context 'with large straight' do
      it 'returns 40 for valid large straight' do
        dice = [1, 2, 3, 4, 5]
        expect(described_class.calculate(11, dice)).to eq(40)
      end

      it 'returns 0 for invalid large straight' do
        dice = [1, 2, 3, 4, 4]
        expect(described_class.calculate(11, dice)).to eq(0)
      end
    end

    context 'with Yahtzee' do
      it 'returns 50 for five of a kind' do
        dice = [4, 4, 4, 4, 4]
        expect(described_class.calculate(12, dice)).to eq(50)
      end

      it 'returns 0 for not five of a kind' do
        dice = [4, 4, 4, 4, 5]
        expect(described_class.calculate(12, dice)).to eq(0)
      end
    end

    context 'with chance' do
      it 'returns sum of all dice' do
        dice = [1, 2, 3, 4, 5]
        expect(described_class.calculate(13, dice)).to eq(15)
      end
    end
  end

  describe '.calculate_total_score' do
    it 'calculates total with bonus' do
      scores = [3, 6, 9, 12, 15, 18, 63, 35, 10, 20, 0, 0, 0, 0, 25, 55, 0]
      expect(described_class.calculate_total_score(scores)).to eq(153)
    end

    it 'calculates total without bonus' do
      scores = [1, 2, 3, 4, 5, 6, 21, 0, 10, 20, 0, 0, 0, 0, 25, 55, 0]
      expect(described_class.calculate_total_score(scores)).to eq(76)
    end
  end
end
