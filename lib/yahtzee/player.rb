# frozen_string_literal: true

require_relative 'score_calculator'

module Yahtzee
  class Player
    attr_reader :id, :name, :scores, :used_categories
    attr_accessor :total_score

    def initialize(name:, id: nil)
      @id = id
      @name = name
      @scores = Array.new(17, 0)
      @used_categories = []
      @total_score = 0
    end

    def add_score(category, points)
      validate_category!(category)
      validate_category_not_used!(category)

      @scores[category_index(category)] = points
      @used_categories << category
      update_totals
    end

    def category_used?(category)
      @used_categories.include?(category)
    end

    def available_categories
      (1..13).to_a - @used_categories
    end

    def all_categories_used?
      @used_categories.size >= 13
    end

    def upper_section_total
      @scores[6]
    end

    def bonus
      @scores[7]
    end

    def lower_section_total
      @scores[15]
    end

    def to_h
      {
        id: @id,
        name: @name,
        scores: @scores,
        used_categories: @used_categories,
        total_score: @total_score
      }
    end

    def self.from_h(data)
      player = new(id: data[:id], name: data[:name])
      player.instance_variable_set(:@scores, data[:scores])
      player.instance_variable_set(:@used_categories, data[:used_categories])
      player.instance_variable_set(:@total_score, data[:total_score])
      player
    end

    private

    def validate_category!(category)
      raise ArgumentError, 'Invalid category' unless category.between?(1, 13)
    end

    def validate_category_not_used!(category)
      raise ArgumentError, 'Category already used' if category_used?(category)
    end

    def category_index(category)
      if category.between?(1, 6)
        category - 1
      else
        category + 1
      end
    end

    def update_totals
      @scores[6] = ScoreCalculator.calculate_upper_section_total(@scores)
      @scores[7] = ScoreCalculator.calculate_bonus(@scores[6])
      @scores[15] = ScoreCalculator.calculate_lower_section_total(@scores)
      @total_score = ScoreCalculator.calculate_total_score(@scores)
      @scores[16] = @total_score
    end
  end
end
