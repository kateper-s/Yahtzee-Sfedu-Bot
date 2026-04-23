# frozen_string_literal: true

require 'spec_helper'
require_relative '../../../lib/yahtzee/dice'

RSpec.describe Yahtzee::Dice do
  let(:dice) { described_class.new }

  describe '#initialize' do
    it 'creates dice with 3 max rolls by default' do
      expect(dice.max_rolls).to eq(3)
      expect(dice.rolls_left).to eq(3)
    end

    it 'creates dice with custom max_rolls' do
      dice_custom = described_class.new(max_rolls: 5)
      expect(dice_custom.max_rolls).to eq(5)
      expect(dice_custom.rolls_left).to eq(5)
    end

    it 'initializes with empty values' do
      expect(dice.values).to be_empty
    end

    it 'is not rolled initially' do
      expect(dice.rolled?).to be false
    end
  end

  describe '#roll' do
    it 'rolls all 5 dice when called without arguments' do
      dice.roll
      expect(dice.values.size).to eq(5)
    end

    it 'rolls all 5 dice when called with nil' do
      dice.roll(nil)
      expect(dice.values.size).to eq(5)
    end

    it 'rolls all 5 dice when called with empty array' do
      dice.roll([])
      expect(dice.values.size).to eq(5)
    end

    it 'generates values between 1 and 6' do
      dice.roll
      expect(dice.values.all? { |v| v.between?(1, 6) }).to be true
    end

    it 'decrements rolls_left' do
      expect { dice.roll }.to change(dice, :rolls_left).from(3).to(2)
    end

    it 'sets rolled? to true' do
      dice.roll
      expect(dice.rolled?).to be true
    end

    it 'returns true on successful roll' do
      expect(dice.roll).to be true
    end

    it 'returns false when no rolls left' do
      3.times { dice.roll }
      expect(dice.roll).to be false
    end

    it 'rerolls specified positions when positions array provided' do
      dice.roll
      old_values = dice.values.dup
      dice.roll([1, 3])
      expect(dice.values[0]).not_to eq(old_values[0])
      expect(dice.values[2]).not_to eq(old_values[2])
    end

    it 'ignores invalid positions' do
      dice.roll
      old_values = dice.values.dup
      dice.roll([10, -1, 0])
      expect(dice.values).to eq(old_values)
    end

    it 'accepts position as integer' do
      dice.roll
      expect { dice.roll([1]) }.not_to raise_error
    end

    it 'handles multiple positions correctly' do
      dice.roll
      old_values = dice.values.dup
      dice.roll([1, 2, 3, 4, 5])
      expect(dice.values).not_to eq(old_values)
    end

    it 'returns false when rolling positions before any roll' do
      expect(dice.roll([1])).to be false
    end
  end

  describe '#reset' do
    before { dice.roll }

    it 'clears values' do
      dice.reset
      expect(dice.values).to be_empty
    end

    it 'resets rolls_left to max_rolls' do
      2.times { dice.roll }
      dice.reset
      expect(dice.rolls_left).to eq(3)
    end

    it 'sets rolled? to false' do
      dice.reset
      expect(dice.rolled?).to be false
    end
  end

  describe '#rolled?' do
    it 'returns false for new dice' do
      expect(dice.rolled?).to be false
    end

    it 'returns true after rolling' do
      dice.roll
      expect(dice.rolled?).to be true
    end

    it 'returns false after reset' do
      dice.roll
      dice.reset
      expect(dice.rolled?).to be false
    end
  end

  describe '#can_roll?' do
    it 'returns true when rolls_left > 0' do
      expect(dice.can_roll?).to be true
    end

    it 'returns false when rolls_left == 0' do
      3.times { dice.roll }
      expect(dice.can_roll?).to be false
    end

    it 'returns true after reset' do
      3.times { dice.roll }
      dice.reset
      expect(dice.can_roll?).to be true
    end
  end

  describe '#sum' do
    it 'returns 0 for unrolled dice' do
      expect(dice.sum).to eq(0)
    end

    it 'calculates sum of rolled dice' do
      dice.roll
      expect(dice.sum).to eq(dice.values.sum)
    end
  end

  describe '#frequencies' do
    it 'returns empty hash for unrolled dice' do
      expect(dice.frequencies).to eq({})
    end

    it 'counts frequency of each value' do
      dice.roll
      frequencies = dice.frequencies
      expect(frequencies.values.sum).to eq(5)
    end
  end

  describe '#sorted' do
    it 'returns empty array for unrolled dice' do
      expect(dice.sorted).to eq([])
    end

    it 'returns sorted values' do
      dice.roll
      expect(dice.sorted).to eq(dice.values.sort)
    end

    it 'does not modify original values' do
      dice.roll
      original = dice.values.dup
      dice.sorted
      expect(dice.values).to eq(original)
    end
  end

  describe '#uniq_values' do
    it 'returns empty array for unrolled dice' do
      expect(dice.uniq_values).to eq([])
    end

    it 'returns unique values' do
      dice.roll
      expect(dice.uniq_values).to eq(dice.values.uniq)
    end
  end

  describe 'NoRollsLeftError' do
    it 'is defined' do
      expect(defined?(Yahtzee::Dice::NoRollsLeftError)).not_to be_nil
    end
  end

  describe 'edge cases' do
    it 'handles multiple reset and roll cycles' do
      3.times do
        dice.roll
        expect(dice.values.size).to eq(5)
        dice.reset
        expect(dice.values).to be_empty
      end
    end

    it 'decrements rolls_left correctly after multiple rolls' do
      expect(dice.rolls_left).to eq(3)
      dice.roll
      expect(dice.rolls_left).to eq(2)
      dice.roll
      expect(dice.rolls_left).to eq(1)
      dice.roll
      expect(dice.rolls_left).to eq(0)
      dice.roll
      expect(dice.rolls_left).to eq(0)
    end
  end
end
