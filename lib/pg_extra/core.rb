# frozen_string_literal: true

# This class loads the base mechanics of the gem
# isolated in the corresponding folder.

# nodoc
module PGExtra
  require_relative "core/adapters/postgres"
  require_relative "core/railtie"
  require_relative "core/qualified_name"

  def database
    Adapters::Postgres.new
  end
end
