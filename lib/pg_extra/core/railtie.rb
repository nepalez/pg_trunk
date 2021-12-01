# frozen_string_literal: true

# nodoc
module PGExtra
  # Turn in PGExtra-relates stuff in the Rails app
  class Railtie < Rails::Railtie
    initializer("pg_extra.load") do
      # rubocop: disable Lint/EmptyBlock
      ActiveSupport.on_load(:active_record) do
      end
      # rubocop: enable Lint/EmptyBlock
    end
  end
end
