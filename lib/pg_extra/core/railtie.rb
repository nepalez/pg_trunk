# frozen_string_literal: true

# nodoc
module PGExtra
  # @private
  # Turn in PGExtra-relates stuff in the Rails app
  class Railtie < Rails::Railtie
    require_relative "railtie/command_recorder"
    require_relative "railtie/custom_types"
    require_relative "railtie/migration"
    require_relative "railtie/migrator"
    require_relative "railtie/schema_dumper"
    require_relative "railtie/schema_migration"
    require_relative "railtie/statements"

    initializer("pg_extra.load") do
      ActiveSupport.on_load(:active_record) do
        # overload schema dumper to use gem-specific object fetchers
        ActiveRecord::SchemaDumper.prepend PGExtra::SchemaDumper
        # add custom type casting
        ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.prepend PGExtra::CustomTypes
        # add migration methods
        ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.prepend PGExtra::Statements
        # register those methods for migration directions
        ActiveRecord::Migration::CommandRecorder.include PGExtra::CommandRecorder
        # support the registry table `pg_extra` in addition to `schema_migrations`
        ActiveRecord::SchemaMigration.prepend PGExtra::SchemaMigration
        # fix migration to enable different syntax without the name of the table
        ActiveRecord::Migration.prepend PGExtra::Migration
        # make the migrator to remove stale records from `pg_extra`
        ActiveRecord::Migrator.prepend PGExtra::Migrator
      end
    end
  end
end
