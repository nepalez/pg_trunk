# frozen_string_literal: true

ENV["RAILS_ENV"] = "test"

require "pry"
require "pry-byebug"
require "database_cleaner/active_record"
require "pg_trunk"
require "rspec/its"
require "test_prof/recipes/rspec/before_all"

require File.expand_path("dummy/config/environment", __dir__)

# noinspection RubyResolve
Dir["spec/support/**/*.rb"].sort.each { |file| load file }

RSpec.configure do |config|
  config.example_status_persistence_file_path = ".rspec_status"
  config.order = "random"
  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  # Filter examples by server version
  server_version = PGTrunk.database.server_version.first(2).to_i
  config.filter_run_excluding(before_version: ->(v) { v <= server_version })
  config.filter_run_excluding(since_version: ->(v) { v > server_version })
end
