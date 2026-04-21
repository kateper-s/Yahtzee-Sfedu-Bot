# frozen_string_literal: true

module Yahtzee
  class ScoreCalculator
    BONUS_THRESHOLD = 63
    BONUS_POINTS = 35

    CATEGORIES = {
      ones: 1,
      twos: 2,
      threes: 3,
      fours: 4,
      fives: 5,
      sixes: 6,
      three_of_kind: 7,
      four_of_kind: 8,
      full_house: 9,
      small_straight: 10,
      large_straight: 11,
      yahtzee: 12,
      chance: 13
    }.freeze

    class << self
      def calculate(category, dice_values)
        case category
        when 1..6 then calculate_numbers(category, dice_values)
        when 7 then calculate_three_of_kind(dice_values)
        when 8 then calculate_four_of_kind(dice_values)
        when 9 then calculate_full_house(dice_values)
        when 10 then calculate_small_straight(dice_values)
        when 11 then calculate_large_straight(dice_values)
        when 12 then calculate_yahtzee(dice_values)
        when 13 then calculate_chance(dice_values)
        else 0
        end
      end

      def calculate_upper_section_total(scores)
        scores[0..5].sum
      end

      def calculate_bonus(upper_total)
        upper_total >= BONUS_THRESHOLD ? BONUS_POINTS : 0
      end

      def calculate_lower_section_total(scores)
        scores[8..14].sum
      end

      def calculate_total_score(scores)
        upper_total = calculate_upper_section_total(scores)
        bonus = calculate_bonus(upper_total)
        lower_total = calculate_lower_section_total(scores)

        upper_total + bonus + lower_total
      end

      private

      def calculate_numbers(number, dice)
        dice.count { |d| d == number } * number
      end

      def calculate_three_of_kind(dice)
        return 0 unless dice.tally.values.max >= 3

        dice.sum
      end

      def calculate_four_of_kind(dice)
        return 0 unless dice.tally.values.max >= 4

        dice.sum
      end

      def calculate_full_house(dice)
        counts = dice.tally.values.sort
        return 25 if counts == [2, 3]

        0
      end

      def calculate_small_straight(dice)
        sorted = dice.sort.uniq
        consecutive_count = count_consecutive(sorted)
        consecutive_count >= 3 ? 30 : 0
      end

      def calculate_large_straight(dice)
        sorted = dice.sort
        return 40 if sorted.each_cons(2).all? { |a, b| b - a == 1 }

        0
      end

      def calculate_yahtzee(dice)
        return 50 if dice.uniq.size == 1

        0
      end

      def calculate_chance(dice)
        dice.sum
      end

      def count_consecutive(sorted_array)
        count = 0
        max_count = 0

        (0...sorted_array.size - 1).each do |i|
          if sorted_array[i + 1] - sorted_array[i] == 1
            count += 1
            max_count = [max_count, count].max
          else
            count = 0
          end
        end

        max_count
      end
    end
  end
end
