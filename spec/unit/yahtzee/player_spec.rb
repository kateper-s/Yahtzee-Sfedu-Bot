# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Yahtzee::Player do
  let(:player) { described_class.new(name: 'Alice') }
  let(:player_with_id) { described_class.new(id: 123, name: 'Bob') }

  describe '#initialize' do
    it 'creates a player with name' do
      expect(player.name).to eq('Alice')
      expect(player.id).to be_nil
    end

    it 'creates a player with id and name' do
      expect(player_with_id.name).to eq('Bob')
      expect(player_with_id.id).to eq(123)
    end

    it 'initializes empty scores array' do
      expect(player.scores).to be_an(Array)
      expect(player.scores.size).to eq(17)
      expect(player.scores.all? { |s| s == 0 }).to be true
    end

    it 'initializes empty used_categories' do
      expect(player.used_categories).to be_empty
    end

    it 'initializes total_score to 0' do
      expect(player.total_score).to eq(0)
    end
  end

  describe '#add_score' do
    context 'with valid category' do
      it 'adds score for numbers category (1-6)' do
        player.add_score(1, 5)
        expect(player.scores[0]).to eq(5)
        expect(player.used_categories).to include(1)
      end

      it 'adds score for three of a kind (7)' do
        player.add_score(7, 20)
        expect(player.scores[8]).to eq(20)
        expect(player.used_categories).to include(7)
      end

      it 'adds score for four of a kind (8)' do
        player.add_score(8, 25)
        expect(player.scores[9]).to eq(25)
        expect(player.used_categories).to include(8)
      end

      it 'adds score for full house (9)' do
        player.add_score(9, 25)
        expect(player.scores[10]).to eq(25)
        expect(player.used_categories).to include(9)
      end

      it 'adds score for small straight (10)' do
        player.add_score(10, 30)
        expect(player.scores[11]).to eq(30)
        expect(player.used_categories).to include(10)
      end

      it 'adds score for large straight (11)' do
        player.add_score(11, 40)
        expect(player.scores[12]).to eq(40)
        expect(player.used_categories).to include(11)
      end

      it 'adds score for yahtzee (12)' do
        player.add_score(12, 50)
        expect(player.scores[13]).to eq(50)
        expect(player.used_categories).to include(12)
      end

      it 'adds score for chance (13)' do
        player.add_score(13, 22)
        expect(player.scores[14]).to eq(22)
        expect(player.used_categories).to include(13)
      end

      it 'updates upper section total' do
        player.add_score(1, 3)
        player.add_score(2, 6)
        player.add_score(3, 9)

        expect(player.scores[6]).to eq(18) # Верхний балл
      end

      it 'adds bonus when upper section reaches 63' do
        # Набираем 63+ очков в верхней секции
        player.add_score(1, 3)  # 3
        player.add_score(2, 6)  # 9
        player.add_score(3, 9)  # 18
        player.add_score(4, 12) # 30
        player.add_score(5, 15) # 45
        player.add_score(6, 18) # 63

        expect(player.scores[6]).to eq(63)
        expect(player.scores[7]).to eq(35) # Бонус
      end

      it 'does not add bonus when upper section below 63' do
        player.add_score(1, 2)
        player.add_score(2, 4)
        player.add_score(3, 6)

        expect(player.scores[6]).to eq(12)
        expect(player.scores[7]).to eq(0)
      end

      it 'updates lower section total' do
        player.add_score(7, 20)
        player.add_score(13, 15)

        expect(player.scores[15]).to eq(35) # Нижний балл
      end

      it 'updates total score correctly' do
        player.add_score(1, 5)
        player.add_score(2, 10)
        player.add_score(3, 15)
        player.add_score(7, 20)
        player.add_score(13, 10)

        # Верхний балл: 30, Бонус: 0, Нижний балл: 30, Итого: 60
        expect(player.total_score).to eq(60)
        expect(player.scores[16]).to eq(60)
      end

      it 'updates total score with bonus' do
        player.add_score(1, 10)
        player.add_score(2, 10)
        player.add_score(3, 10)
        player.add_score(4, 10)
        player.add_score(5, 10)
        player.add_score(6, 13) # Верхний балл: 63
        player.add_score(7, 20)
        player.add_score(13, 10)

        # Верхний балл: 63, Бонус: 35, Нижний балл: 30, Итого: 128
        expect(player.total_score).to eq(128)
        expect(player.scores[16]).to eq(128)
      end
    end

    context 'with invalid category' do
      it 'raises error for category less than 1' do
        expect { player.add_score(0, 10) }.to raise_error(ArgumentError, /Invalid category/)
      end

      it 'raises error for category greater than 13' do
        expect { player.add_score(14, 10) }.to raise_error(ArgumentError, /Invalid category/)
      end

      it 'raises error when category already used' do
        player.add_score(1, 5)
        expect { player.add_score(1, 10) }.to raise_error(ArgumentError, /Category already used/)
      end
    end
  end

  describe '#category_used?' do
    it 'returns true for used category' do
      player.add_score(1, 5)
      expect(player.category_used?(1)).to be true
    end

    it 'returns false for unused category' do
      expect(player.category_used?(1)).to be false
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
      player.add_score(7, 20)
      player.add_score(13, 15)

      expected = (1..13).to_a - [1, 7, 13]
      expect(player.available_categories).to match_array(expected)
    end

    it 'returns empty array when all categories used' do
      (1..13).each { |cat| player.add_score(cat, cat * 2) }

      expect(player.available_categories).to be_empty
    end
  end

  describe '#all_categories_used?' do
    it 'returns false initially' do
      expect(player.all_categories_used?).to be false
    end

    it 'returns false when some categories remain' do
      player.add_score(1, 5)
      player.add_score(2, 10)

      expect(player.all_categories_used?).to be false
    end

    it 'returns true when all 13 categories used' do
      (1..13).each { |cat| player.add_score(cat, cat * 2) }

      expect(player.all_categories_used?).to be true
    end
  end

  describe '#upper_section_total' do
    it 'returns 0 initially' do
      expect(player.upper_section_total).to eq(0)
    end

    it 'returns sum of upper section scores' do
      player.add_score(1, 3)
      player.add_score(2, 6)
      player.add_score(3, 9)

      expect(player.upper_section_total).to eq(18)
    end
  end

  describe '#bonus' do
    it 'returns 0 initially' do
      expect(player.bonus).to eq(0)
    end

    it 'returns 35 when upper section >= 63' do
      player.add_score(1, 20)
      player.add_score(2, 20)
      player.add_score(3, 23)

      expect(player.bonus).to eq(35)
    end

    it 'returns 0 when upper section < 63' do
      player.add_score(1, 20)
      player.add_score(2, 20)

      expect(player.bonus).to eq(0)
    end
  end

  describe '#lower_section_total' do
    it 'returns 0 initially' do
      expect(player.lower_section_total).to eq(0)
    end

    it 'returns sum of lower section scores' do
      player.add_score(7, 20)
      player.add_score(9, 25)
      player.add_score(13, 15)

      expect(player.lower_section_total).to eq(60)
    end
  end

  describe '#to_h' do
    it 'returns hash representation of player' do
      player.add_score(1, 5)
      player.add_score(7, 20)

      hash = player.to_h

      expect(hash).to be_a(Hash)
      expect(hash[:name]).to eq('Alice')
      expect(hash[:scores]).to be_an(Array)
      expect(hash[:used_categories]).to contain_exactly(1, 7)
      expect(hash[:total_score]).to be_a(Integer)
    end

    it 'includes id when present' do
      hash = player_with_id.to_h
      expect(hash[:id]).to eq(123)
    end

    it 'includes nil id when not present' do
      hash = player.to_h
      expect(hash[:id]).to be_nil
    end
  end

  describe '.from_h' do
    let(:hash_data) do
      {
        id: 456,
        name: 'Charlie',
        scores: [1, 2, 3, 0, 0, 0, 6, 0, 20, 0, 0, 0, 0, 0, 15, 35, 76],
        used_categories: [1, 2, 3, 7, 13],
        total_score: 76
      }
    end

    it 'creates player from hash' do
      player = described_class.from_h(hash_data)

      expect(player.id).to eq(456)
      expect(player.name).to eq('Charlie')
      expect(player.scores).to eq(hash_data[:scores])
      expect(player.used_categories).to match_array([1, 2, 3, 7, 13])
      expect(player.total_score).to eq(76)
    end

    it 'creates player without id' do
      hash_data.delete(:id)
      player = described_class.from_h(hash_data)

      expect(player.id).to be_nil
      expect(player.name).to eq('Charlie')
    end
  end

  describe 'edge cases' do
    it 'handles zero scores correctly' do
      player.add_score(1, 0)
      expect(player.scores[0]).to eq(0)
      expect(player.upper_section_total).to eq(0)
    end

    it 'handles multiple scores in same category correctly' do
      player.add_score(1, 5)
      expect(player.scores[0]).to eq(5)

      # Попытка добавить ещё раз должна вызвать ошибку
      expect { player.add_score(1, 10) }.to raise_error(ArgumentError)
    end

    it 'maintains correct scores when categories added in different order' do
      player.add_score(13, 25) # Chance
      player.add_score(7, 18)  # Three of a kind
      player.add_score(1, 3)   # Ones

      expect(player.scores[0]).to eq(3)   # Ones
      expect(player.scores[8]).to eq(18)  # Three of a kind
      expect(player.scores[14]).to eq(25) # Chance
    end

    it 'calculates correct total when upper section exactly 63' do
      player.add_score(1, 10)
      player.add_score(2, 10)
      player.add_score(3, 10)
      player.add_score(4, 10)
      player.add_score(5, 10)
      player.add_score(6, 13) # Exactly 63

      expect(player.upper_section_total).to eq(63)
      expect(player.bonus).to eq(35)
    end

    it 'handles very large scores' do
      player.add_score(7, 1000)
      expect(player.scores[8]).to eq(1000)
      expect(player.lower_section_total).to eq(1000)
    end

    it 'handles negative scores gracefully' do
      # Хотя игра не должна давать отрицательные очки, проверяем поведение
      player.add_score(1, -5)
      expect(player.scores[0]).to eq(-5)
    end
  end

  describe 'score indices' do
    it 'maps categories to correct score array indices' do
      test_cases = {
        1 => 0,   # Единицы
        2 => 1,   # Двойки
        3 => 2,   # Тройки
        4 => 3,   # Четвёрки
        5 => 4,   # Пятёрки
        6 => 5,   # Шестёрки
        7 => 8,   # Три равных
        8 => 9,   # Четыре равных
        9 => 10,  # Фул-хаус
        10 => 11, # Малая последовательность
        11 => 12, # Большая последовательность
        12 => 13, # Yahtzee
        13 => 14  # Шанс
      }

      test_cases.each do |category, expected_index|
        player = described_class.new(name: 'Test')
        player.add_score(category, category * 2)

        expect(player.scores[expected_index]).to eq(category * 2)
      end
    end

    it 'has correct indices for totals' do
      expect(player.scores[6]).to eq(0)  # Верхний балл
      expect(player.scores[7]).to eq(0)  # Бонус
      expect(player.scores[15]).to eq(0) # Нижний балл
      expect(player.scores[16]).to eq(0) # Итоговый счёт
    end
  end
end