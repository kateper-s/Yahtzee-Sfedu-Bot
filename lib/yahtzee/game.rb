# frozen_string_literal: true

class Yahtzee::Game
  class Error < StandardError; end
  class GameNotStartedError < Error; end
  class GameAlreadyStartedError < Error; end
  class InvalidPlayerCountError < Error; end
  class PlayerNotFoundError < Error; end
  class NotPlayersTurnError < Error; end
  class DiceNotRolledError < Error; end

  MAX_PLAYERS = 4
  MIN_PLAYERS = 1

  attr_reader :id, :chat_id, :players, :current_player_index,
              :dice, :state, :created_at, :updated_at

  def initialize(chat_id:, id: nil)
    @id = id
    @chat_id = chat_id
    @players = []
    @state = :waiting_for_players
    @created_at = Time.now
    @updated_at = Time.now
    @dice = Dice.new
  end

  def add_player(name, player_id = nil)
    validate_can_add_player!(name)

    player = Player.new(id: player_id, name:)
    @players << player
    @updated_at = Time.now
    player
  end

  def remove_player(name)
    validate_game_not_started!

    @players.reject! { |p| p.name == name }
    @updated_at = Time.now
  end

  def start
    validate_can_start!

    @state = :in_progress
    @current_player_index = 0
    @updated_at = Time.now
    true
  end

  def roll_dice
    validate_game_in_progress!
    validate_dice_can_be_rolled!

    @dice.roll_all
    @updated_at = Time.now
    @dice.values
  end

  def reroll_dice(positions)
    validate_game_in_progress!
    validate_dice_rolled!
    validate_dice_can_be_rolled!

    @dice.roll_positions(positions)
    @updated_at = Time.now
    @dice.values
  end

  def select_category(category, player_name)
    validate_game_in_progress!
    validate_player_turn!(player_name)
    validate_dice_rolled!

    player = find_player!(player_name)
    points = ScoreCalculator.calculate(category, @dice.values)

    player.add_score(category, points)
    @dice.reset
    next_turn
    @updated_at = Time.now

    points
  end

  def current_player
    @players[@current_player_index] if @state == :in_progress
  end

  def game_over?
    @players.all?(&:all_categories_used?)
  end

  def winner
    return nil unless game_over?

    max_score = @players.map(&:total_score).max
    winners = @players.select { |p| p.total_score == max_score }
    winners.size == 1 ? winners.first : winners
  end

  def finish
    @state = :finished
    @updated_at = Time.now
  end

  def to_h
    {
      id: @id,
      chat_id: @chat_id,
      players: @players.map(&:to_h),
      current_player_index: @current_player_index,
      state: @state.to_s,
      created_at: @created_at.to_s,
      updated_at: @updated_at.to_s
    }
  end

  def self.from_h(data, dice_values = nil)
    game = new(id: data[:id], chat_id: data[:chat_id])
    game.instance_variable_set(:@players, data[:players].map { |p| Player.from_h(p) })
    game.instance_variable_set(:@current_player_index, data[:current_player_index])
    game.instance_variable_set(:@state, data[:state].to_sym)
    game.instance_variable_set(:@created_at, Time.parse(data[:created_at]))
    game.instance_variable_set(:@updated_at, Time.parse(data[:updated_at]))

    if dice_values
      game.instance_variable_set(:@dice, Dice.new)
      game.dice.instance_variable_set(:@values, dice_values)
    end

    game
  end

  protected

  attr_writer :state, :current_player_index, :created_at, :updated_at

  private

  def validate_can_add_player!(name)
    validate_game_not_started!
    validate_player_count!
    validate_player_name_unique!(name)
  end

  def validate_game_not_started!
    return if @state == :waiting_for_players

    raise GameAlreadyStartedError, 'Game has already started'
  end

  def validate_player_count!
    return if @players.size < MAX_PLAYERS

    raise InvalidPlayerCountError, "Maximum #{MAX_PLAYERS} players allowed"
  end

  def validate_player_name_unique!(name)
    return unless @players.any? { |p| p.name == name }

    raise ArgumentError, 'Player with this name already exists'
  end

  def validate_can_start!
    validate_game_not_started!
    return if @players.size >= MIN_PLAYERS

    raise InvalidPlayerCountError, "Need at least #{MIN_PLAYERS} player(s)"
  end

  def validate_game_in_progress!
    return if @state == :in_progress

    raise GameNotStartedError, 'Game is not in progress'
  end

  def validate_dice_can_be_rolled!
    return if @dice.can_roll?

    raise Dice::NoRollsLeftError, 'No rolls left'
  end

  def validate_dice_rolled!
    return if @dice.rolled?

    raise DiceNotRolledError, 'Dice must be rolled first'
  end

  def validate_player_turn!(player_name)
    current = current_player
    return if current && current.name == player_name

    raise NotPlayersTurnError, "It's #{current&.name}'s turn"
  end

  def find_player!(name)
    player = @players.find { |p| p.name == name }
    raise PlayerNotFoundError, "Player #{name} not found" unless player

    player
  end

  def next_turn
    @current_player_index = (@current_player_index + 1) % @players.size
  end
end
