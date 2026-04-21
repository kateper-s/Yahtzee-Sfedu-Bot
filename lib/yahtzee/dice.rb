# frozen_string_literal: true

module Yahtzee
  class Dice
    DICE_EMOJIS = {
      1 => '⚀', 2 => '⚁', 3 => '⚂',
      4 => '⚃', 5 => '⚄', 6 => '⚅'
    }.freeze

    attr_reader :values, :max_rolls, :rolls_left

    def initialize(max_rolls: 3)
      @values = []
      @max_rolls = max_rolls
      @rolls_left = max_rolls
    end

    def roll(positions = nil)
      if positions.nil? || positions.empty?
        roll_all
      else
        roll_positions(positions)
      end
    end

    def roll_all
      return false if @rolls_left <= 0

      @values = Array.new(5) { rand(1..6) }
      @rolls_left -= 1
      true
    end

    def roll_positions(positions)
      return false if @rolls_left <= 0
      return false if @values.empty?

      positions.each do |pos|
        next unless valid_position?(pos)

        @values[pos - 1] = rand(1..6)
      end
      @rolls_left -= 1
      true
    end

    def reset
      @values = []
      @rolls_left = @max_rolls
    end

    def rolled?
      !@values.empty?
    end

    def can_roll?
      @rolls_left.positive?
    end

    def to_emojis
      @values.map { |v| DICE_EMOJIS[v] }.join(' ')
    end

    def sum
      @values.sum
    end

    def frequencies
      @values.tally
    end

    def sorted
      @values.sort
    end

    def uniq_values
      @values.uniq
    end

    private

    def valid_position?(position)
      position.between?(1, 5)
    end
  end
end
