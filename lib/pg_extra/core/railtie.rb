# frozen_string_literal: true

# nodoc
module PGExtra
  # Turn in PGExtra-relates stuff in the Rails app
  class Railtie < Rails::Railtie
    require_relative "railtie/migrator"
    require_relative "railtie/schema_migration"

    initializer("pg_extra.load") do
      ActiveSupport.on_load(:active_record) do
        # support the registry table `pg_extra` in addition to `schema_migrations`
        ActiveRecord::SchemaMigration.prepend PGExtra::SchemaMigration
        # make the migrator to remove stale records from `pg_extra`
        ActiveRecord::Migrator.prepend PGExtra::Migrator
      end
    end
  end
end
