# frozen_string_literal: true

source 'https://rubygems.org'

ruby '3.3.6'

gem 'telegram-bot-ruby', '~> 1.0'
gem 'sqlite3', '~> 1.6'
gem 'sequel', '~> 5.70'
gem 'dotenv', '~> 2.8'
gem 'logger', '~> 1.5'
gem 'json', '~> 2.6'
gem 'i18n', '~> 1.14'

group :development, :test do
  gem 'rspec', '~> 3.12'
  gem 'rubocop', '~> 1.50', require: false
  gem 'rubocop-rspec', '~> 2.20', require: false
  gem 'factory_bot', '~> 6.2'
  gem 'faker', '~> 3.2'
  gem 'pry', '~> 0.14'
  gem 'pry-byebug', '~> 3.10'
  gem 'simplecov', '~> 0.22', require: false
end

group :test do
  gem 'webmock', '~> 3.19'
  gem 'timecop', '~> 0.9'
  gem 'database_cleaner-sequel', '~> 2.0'
end