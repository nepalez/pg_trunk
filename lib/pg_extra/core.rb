# frozen_string_literal: true

# This class loads the base mechanics of the gem
# isolated in the corresponding folder.

# nodoc
module PGExtra
  require_relative "core/adapters/postgres"

  def database
    Adapters::Postgres.new
  end
end
