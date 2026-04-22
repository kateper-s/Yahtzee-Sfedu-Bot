# frozen_string_literal: true

require 'sequel'
require 'json'
require 'logger'
require 'fileutils'
require_relative 'game'

module Yahtzee
  class Persistence
    def initialize(db_path = 'db/yahtzee.db')
      db_dir = File.dirname(db_path)
      FileUtils.mkdir_p(db_dir) unless File.exist?(db_dir)

      @db = Sequel.sqlite(db_path)
      @db.loggers << Logger.new($stdout) if ENV['DEBUG']
      setup_tables
    end

    def save_game(game)
      if game.id
        update_game(game)
      else
        insert_game(game)
      end
    end

    def load_game(chat_id)
      record = games_table.where(chat_id:).first
      return nil unless record

      puts "Загружаем игру из БД: #{record.inspect}"
      game_data = JSON.parse(record[:game_data], symbolize_names: true)
      Game.from_h(game_data)
    end

    def delete_game(chat_id)
      games_table.where(chat_id:).delete
    end

    def save_player_stats(user_id, player_name, score, won: false)
      player_stats_table.insert(
        user_id:,
        player_name:,
        score:,
        won: won ? 1 : 0,
        played_at: Time.now
      )
    end

    def get_player_stats(user_id)
      stats = player_stats_table.where(user_id:)
      {
        games_played: stats.count,
        average_score: stats.avg(:score).to_f.round(2),
        highest_score: stats.max(:score),
        wins: stats.where(won: 1).count
      }
    end

    def get_leaderboard(limit = 10)
      player_stats_table
        .select_group(:user_id)
        .select_append { max(:player_name).as(:player_name) }
        .select_append { avg(score).as(:avg_score) }
        .select_append { count(:id).as(:games) }
        .select_append { sum(:won).as(:wins) }
        .order(Sequel.desc(:wins), Sequel.desc(:avg_score))
        .limit(limit)
        .all
    end

    private

    def games_table
      @db[:games]
    end

    def player_stats_table
      @db[:player_stats]
    end

    def setup_tables
      @db.create_table? :games do
        primary_key :id
        Integer :chat_id, null: false
        String :game_data, text: true, null: false
        DateTime :created_at, default: Sequel::CURRENT_TIMESTAMP
        DateTime :updated_at, default: Sequel::CURRENT_TIMESTAMP
      end

      # Безопасное добавление индекса (исправление ошибки)
      existing_index = @db.indexes(:games).values.any? { |idx| idx[:columns] == [:chat_id] }
      unless existing_index
        @db.add_index :games, :chat_id, unique: true
      end

      @db.create_table? :player_stats do
        primary_key :id
        Integer :user_id # Telegram ID пользователя
        String :player_name, null: false
        Integer :score, null: false
        Integer :won, default: 0
        DateTime :played_at, default: Sequel::CURRENT_TIMESTAMP
      end

      # Миграция: добавить колонку user_id, если её нет (для старых БД)
      return if @db.schema(:player_stats).any? { |col| col.first == :user_id }

      @db.alter_table(:player_stats) do
        add_column :user_id, Integer
      end
    end

    def insert_game(game)
      game_id = games_table.insert(
        chat_id: game.chat_id,
        game_data: game.to_h.to_json,
        created_at: game.created_at,
        updated_at: game.updated_at
      )
      game.instance_variable_set(:@id, game_id)
      puts "Игра вставлена в БД с ID: #{game_id}"
      game
    rescue Sequel::UniqueConstraintViolation
      puts 'Игра для этого чата уже существует, обновляем...'
      update_game(game)
    end

    def update_game(game)
      count = games_table
              .where(id: game.id)
              .update(
                game_data: game.to_h.to_json,
                updated_at: game.updated_at
              )
      puts "Обновлено строк: #{count}"
      game
    rescue StandardError => e
      puts "Ошибка при обновлении игры: #{e.message}"
      puts e.backtrace.join("\n")
      raise
    end
  end
end
