# frozen_string_literal: true

ENV["RAILS_ENV"] = "test"

require "pry"
require "pry-byebug"
require "database_cleaner/active_record"
require "pg_extra"
require "rspec/its"

require File.expand_path("dummy/config/environment", __dir__)

# noinspection RubyResolve
Dir["spec/support/**/*.rb"].sort.each { |file| load file }

RSpec.configure do |config|
  config.example_status_persistence_file_path = ".rspec_status"
  config.order = "random"

  config.around(:each, db: true) do |example|
    DatabaseCleaner.start
    example.run
    DatabaseCleaner.clean
  end

  unless defined?(silence_stream)
    require "active_support/testing/stream"
    config.include ActiveSupport::Testing::Stream
  end

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end
