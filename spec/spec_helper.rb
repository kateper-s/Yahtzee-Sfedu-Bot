# frozen_string_literal: true

require 'simplecov'
SimpleCov.start do
  add_filter '/spec/'
  add_filter '/vendor/'

  add_group 'Yahtzee', 'lib/yahtzee'
  add_group 'Bot', 'lib/yahtzee_bot'
end

require 'rspec'
require 'factory_bot'
require 'faker'
require 'timecop'
require 'webmock/rspec'
require 'database_cleaner-sequel'
require 'pry'

require_relative '../lib/yahtzee/game'
require_relative '../lib/yahtzee/player'
require_relative '../lib/yahtzee/dice'
require_relative '../lib/yahtzee/score_calculator'
require_relative '../lib/yahtzee/persistence'

RSpec.configure do |config|
  config.include FactoryBot::Syntax::Methods

  config.before(:suite) do
    FactoryBot.find_definitions
  end

  config.before(:each) do
    DatabaseCleaner.strategy = :transaction
    DatabaseCleaner.start
  end

  config.after(:each) do
    DatabaseCleaner.clean
    Timecop.return
  end

  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
  config.filter_run_when_matching :focus
  config.example_status_persistence_file_path = 'spec/examples.txt'
  config.disable_monkey_patching!
  config.warnings = true
  config.default_formatter = 'doc' if config.files_to_run.one?
  config.order = :random
  Kernel.srand config.seed
end

WebMock.disable_net_connect!(allow_localhost: true)