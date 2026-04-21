# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Yahtzee::Dice do
  let(:dice) { described_class.new }

  describe '#initialize' do
    context 'with default parameters' do
      it 'creates dice with 3 max rolls' do
        expect(dice.max_rolls).to eq(3)
        expect(dice.rolls_left).to eq(3)
      end

      it 'has empty values initially' do
        expect(dice.values).to be_empty
      end

      it 'is not rolled initially' do
        expect(dice.rolled?).to be false
      end
    end

    context 'with custom max_rolls' do
      let(:custom_dice) { described_class.new(max_rolls: 5) }

      it 'creates dice with custom max rolls' do
        expect(custom_dice.max_rolls).to eq(5)
        expect(custom_dice.rolls_left).to eq(5)
      end
    end

    context 'with invalid max_rolls' do
      it 'raises error for negative max_rolls' do
        expect { described_class.new(max_rolls: -1) }.to raise_error(ArgumentError)
      end

      it 'raises error for zero max_rolls' do
        expect { described_class.new(max_rolls: 0) }.to raise_error(ArgumentError)
      end
    end
  end

  describe '#roll' do
    context 'when rolling all dice' do
      it 'generates 5 random values between 1 and 6' do
        dice.roll
        expect(dice.values.size).to eq(5)
        expect(dice.values).to all(be_between(1, 6))
      end

      it 'decrements rolls_left' do
        expect { dice.roll }.to change(dice, :rolls_left).from(3).to(2)
      end

      it 'sets rolled? to true' do
        expect { dice.roll }.to change(dice, :rolled?).from(false).to(true)
      end

      it 'generates different values on subsequent rolls' do
        dice.roll
        first_roll = dice.values.dup

        dice.reset
        dice.roll
        second_roll = dice.values.dup

        # Статистически маловероятно, что оба броска будут идентичны
        expect(first_roll).not_to eq(second_roll)
      end

      it 'returns true on successful roll' do
        expect(dice.roll).to be true
      end

      it 'returns false when no rolls left' do
        3.times { dice.roll }
        expect(dice.roll).to be false
      end

      it 'does not modify values when no rolls left' do
        3.times { dice.roll }
        last_values = dice.values.dup
        dice.roll
        expect(dice.values).to eq(last_values)
      end
    end

    context 'when rolling specific positions' do
      before { dice.roll_all }

      it 'rerolls only specified positions' do
        original_values = dice.values.dup
        dice.roll_positions([1, 3])

        expect(dice.values[0]).not_to eq(original_values[0])
        expect(dice.values[1]).to eq(original_values[1])
        expect(dice.values[2]).not_to eq(original_values[2])
        expect(dice.values[3]).to eq(original_values[3])
        expect(dice.values[4]).to eq(original_values[4])
      end

      it 'handles multiple positions correctly' do
        dice.roll_positions([2, 4, 5])
        expect(dice.values.size).to eq(5)
      end

      it 'ignores invalid positions' do
        original_values = dice.values.dup
        dice.roll_positions([0, 6, 100, -1])

        expect(dice.values).to eq(original_values)
      end

      it 'accepts position as integer' do
        expect { dice.roll_positions(1) }.not_to raise_error
      end

      it 'decrements rolls_left' do
        expect { dice.roll_positions([1, 2]) }.to change(dice, :rolls_left).by(-1)
      end

      it 'returns false when dice not rolled yet' do
        new_dice = described_class.new
        expect(new_dice.roll_positions([1, 2])).to be false
      end

      it 'returns false when no rolls left' do
        2.times { dice.roll_positions([1]) }
        expect(dice.roll_positions([2])).to be false
      end

      it 'maintains values between 1 and 6' do
        dice.roll_positions([1, 2, 3, 4, 5])
        expect(dice.values).to all(be_between(1, 6))
      end
    end

    context 'with edge cases' do
      it 'handles empty positions array' do
        dice.roll_all
        original_values = dice.values.dup
        dice.roll_positions([])

        expect(dice.values).to eq(original_values)
        expect(dice.rolls_left).to eq(2)
      end

      it 'handles nil positions' do
        dice.roll(nil)
        expect(dice.values.size).to eq(5)
      end

      it 'handles string positions' do
        dice.roll_all
        dice.roll_positions(%w[1 2])

        expect(dice.rolls_left).to eq(2)
      end

      it 'handles duplicate positions' do
        dice.roll_all
        original_values = dice.values.dup
        dice.roll_positions([1, 1, 1])

        # Первая позиция переброшена один раз
        expect(dice.values[0]).not_to eq(original_values[0])
        expect(dice.rolls_left).to eq(2)
      end
    end
  end

  describe '#roll_all' do
    it 'rolls all 5 dice' do
      dice.roll_all
      expect(dice.values.size).to eq(5)
    end

    it 'decrements rolls_left' do
      expect { dice.roll_all }.to change(dice, :rolls_left).by(-1)
    end

    it 'returns false when no rolls left' do
      3.times { dice.roll_all }
      expect(dice.roll_all).to be false
    end

    it 'overwrites existing values' do
      dice.roll_all
      first_values = dice.values.dup

      dice.roll_all
      second_values = dice.values.dup

      expect(first_values).not_to eq(second_values)
    end
  end

  describe '#reset' do
    before do
      dice.roll_all
      dice.roll_positions([1, 2])
    end

    it 'clears values' do
      dice.reset
      expect(dice.values).to be_empty
    end

    it 'resets rolls_left to max_rolls' do
      expect { dice.reset }.to change(dice, :rolls_left).from(1).to(3)
    end

    it 'sets rolled? to false' do
      dice.reset
      expect(dice.rolled?).to be false
    end

    it 'returns self for method chaining' do
      expect(dice.reset).to be(dice)
    end
  end

  describe '#rolled?' do
    it 'returns false for new dice' do
      expect(dice.rolled?).to be false
    end

    it 'returns true after rolling' do
      dice.roll_all
      expect(dice.rolled?).to be true
    end

    it 'returns false after reset' do
      dice.roll_all
      dice.reset
      expect(dice.rolled?).to be false
    end

    it 'returns true after partial reroll' do
      dice.roll_all
      dice.roll_positions([1])
      expect(dice.rolled?).to be true
    end
  end

  describe '#can_roll?' do
    it 'returns true when rolls_left > 0' do
      expect(dice.can_roll?).to be true
    end

    it 'returns false when rolls_left == 0' do
      3.times { dice.roll_all }
      expect(dice.can_roll?).to be false
    end

    it 'returns true after reset' do
      3.times { dice.roll_all }
      dice.reset
      expect(dice.can_roll?).to be true
    end
  end

  describe '#to_emojis' do
    it 'returns empty string for unrolled dice' do
      expect(dice.to_emojis).to eq('')
    end

    it 'converts values to dice emojis' do
      dice.instance_variable_set(:@values, [1, 2, 3, 4, 5])
      expect(dice.to_emojis).to eq('⚀ ⚁ ⚂ ⚃ ⚄')
    end

    it 'handles all possible values' do
      (1..6).each do |value|
        dice.instance_variable_set(:@values, [value])
        expect(dice.to_emojis).to match(/[⚀⚁⚂⚃⚄⚅]/)
      end
    end

    it 'joins multiple emojis with spaces' do
      dice.instance_variable_set(:@values, [6, 6, 6])
      expect(dice.to_emojis).to eq('⚅ ⚅ ⚅')
    end
  end

  describe '#sum' do
    it 'returns 0 for empty values' do
      expect(dice.sum).to eq(0)
    end

    it 'calculates sum of all dice' do
      dice.instance_variable_set(:@values, [1, 2, 3, 4, 5])
      expect(dice.sum).to eq(15)
    end

    it 'handles single value' do
      dice.instance_variable_set(:@values, [6])
      expect(dice.sum).to eq(6)
    end

    it 'handles duplicate values' do
      dice.instance_variable_set(:@values, [3, 3, 3])
      expect(dice.sum).to eq(9)
    end
  end

  describe '#frequencies' do
    it 'returns empty hash for empty values' do
      expect(dice.frequencies).to eq({})
    end

    it 'counts frequency of each value' do
      dice.instance_variable_set(:@values, [1, 1, 2, 3, 3])
      expect(dice.frequencies).to eq({ 1 => 2, 2 => 1, 3 => 2 })
    end

    it 'handles all same values' do
      dice.instance_variable_set(:@values, [4, 4, 4, 4, 4])
      expect(dice.frequencies).to eq({ 4 => 5 })
    end

    it 'handles all different values' do
      dice.instance_variable_set(:@values, [1, 2, 3, 4, 5])
      expect(dice.frequencies).to eq({ 1 => 1, 2 => 1, 3 => 1, 4 => 1, 5 => 1 })
    end
  end

  describe '#sorted' do
    it 'returns empty array for empty values' do
      expect(dice.sorted).to eq([])
    end

    it 'returns sorted values' do
      dice.instance_variable_set(:@values, [5, 2, 4, 1, 3])
      expect(dice.sorted).to eq([1, 2, 3, 4, 5])
    end

    it 'does not modify original values' do
      original = [5, 2, 4, 1, 3]
      dice.instance_variable_set(:@values, original.dup)
      dice.sorted
      expect(dice.values).to eq(original)
    end

    it 'handles duplicate values correctly' do
      dice.instance_variable_set(:@values, [3, 1, 3, 2, 1])
      expect(dice.sorted).to eq([1, 1, 2, 3, 3])
    end
  end

  describe '#uniq_values' do
    it 'returns empty array for empty values' do
      expect(dice.uniq_values).to eq([])
    end

    it 'returns unique values' do
      dice.instance_variable_set(:@values, [1, 1, 2, 3, 3])
      expect(dice.uniq_values).to contain_exactly(1, 2, 3)
    end

    it 'returns single value for all same' do
      dice.instance_variable_set(:@values, [4, 4, 4, 4, 4])
      expect(dice.uniq_values).to eq([4])
    end

    it 'preserves order of first occurrence' do
      dice.instance_variable_set(:@values, [5, 3, 1, 3, 5])
      expect(dice.uniq_values).to eq([5, 3, 1])
    end
  end

  describe 'edge cases and error conditions' do
    context 'when dice values are manipulated directly' do
      it 'prevents direct modification of values' do
        dice.roll_all
        values = dice.values
        values[0] = 7

        expect(dice.values[0]).not_to eq(7)
      end
    end

    context 'with large number of operations' do
      it 'handles multiple reset and roll cycles' do
        100.times do
          dice.roll_all
          expect(dice.values.size).to eq(5)
          dice.reset
          expect(dice.values).to be_empty
        end
      end
    end

    context 'when checking state consistency' do
      it 'maintains consistent state after partial operations' do
        dice.roll_all
        expect(dice.rolled?).to be true
        expect(dice.rolls_left).to eq(2)

        dice.roll_positions([1, 2])
        expect(dice.rolled?).to be true
        expect(dice.rolls_left).to eq(1)

        dice.roll_positions([3])
        expect(dice.rolled?).to be true
        expect(dice.rolls_left).to eq(0)

        dice.reset
        expect(dice.rolled?).to be false
        expect(dice.rolls_left).to eq(3)
        expect(dice.values).to be_empty
      end
    end

    context 'with random distribution' do
      it 'generates values with reasonable distribution' do
        frequencies = Hash.new(0)
        10_000.times do
          dice.reset
          dice.roll_all
          dice.each_value { |v| frequencies[v] += 1 }
        end

        # Каждое значение должно появляться примерно с одинаковой частотой
        expected = 50_000 / 6 # 5 кубиков * 10,000 бросков / 6 значений
        frequencies.each_value do |count|
          # Допускаем отклонение в 5%
          expect(count).to be_within(expected * 0.05).of(expected)
        end
      end
    end
  end

  describe 'performance' do
    it 'rolls dice quickly' do
      expect do
        1000.times do
          dice.reset
          dice.roll_all
          2.times { dice.roll_positions([1, 2]) }
        end
      end.to perform_under(0.5).sec
    end
  end

  describe 'serialization' do
    it 'can be converted to hash' do
      dice.roll_all
      hash = {
        values: dice.values,
        max_rolls: dice.max_rolls,
        rolls_left: dice.rolls_left
      }

      expect(hash[:values]).to be_an(Array)
      expect(hash[:max_rolls]).to eq(3)
      expect(hash[:rolls_left]).to eq(2)
    end

    it 'can be restored from hash' do
      dice.roll_all
      saved_values = dice.values.dup
      saved_rolls_left = dice.rolls_left

      new_dice = described_class.new
      new_dice.instance_variable_set(:@values, saved_values)
      new_dice.instance_variable_set(:@rolls_left, saved_rolls_left)

      expect(new_dice.values).to eq(saved_values)
      expect(new_dice.rolls_left).to eq(saved_rolls_left)
      expect(new_dice.rolled?).to be true
    end
  end

  describe 'Yahtzee::Dice::NoRollsLeftError' do
    it 'is defined' do
      expect { raise Yahtzee::Dice::NoRollsLeftError }.to raise_error(StandardError)
    end

    it 'has descriptive message' do
      error = Yahtzee::Dice::NoRollsLeftError.new('No rolls left')
      expect(error.message).to eq('No rolls left')
    end
  end
end
