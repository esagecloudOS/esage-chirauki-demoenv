# frozen_string_literal: true

source 'https://rubygems.org'

gem 'berkshelf'
gem 'chef', '~> 12.16.42'

gem 'cookstyle', '~> 2.0.0', group: :lint
gem 'dep_selector'
gem 'foodcritic', '~> 10.3.1', group: :lint

group :integration, :test, :development do
  gem 'abiquo-api', '~> 0.1.2'
  gem 'kitchen-vagrant', '~> 0.20.0'
  gem 'serverspec', '~> 2.38.0'
  gem 'test-kitchen', '~> 1.15.0'
  gem 'kitchen-digitalocean', '~> 0.9.5'
end
