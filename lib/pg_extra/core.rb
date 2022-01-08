# frozen_string_literal: true

# This class loads the base mechanics of the gem
# isolated in the corresponding folder.

# nodoc
module PGExtra
  require_relative "core/adapters/postgres"
  require_relative "core/railtie"
  require_relative "core/qualified_name"
  require_relative "core/registry"
  require_relative "core/serializers"
  require_relative "core/validators"
  require_relative "core/operation"
  require_relative "core/dependencies_resolver"

  # @private
  def database
    Adapters::Postgres.new
  end
end
