# frozen_string_literal: true

# nodoc
module PGTrunk
  # @private
  # Turn in PGTrunk-relates stuff in the Rails app
  class Railtie < Rails::Railtie
    require_relative "railtie/command_recorder"
    require_relative "railtie/custom_types"
    require_relative "railtie/migration"
    require_relative "railtie/migrator"
    require_relative "railtie/schema_dumper"
    require_relative "railtie/schema_migration"
    require_relative "railtie/statements"

    initializer("pg_trunk.load") do
      ActiveSupport.on_load(:active_record) do
        # overload schema dumper to use gem-specific object fetchers
        ActiveRecord::SchemaDumper.prepend PGTrunk::SchemaDumper
        # add custom type casting
        ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.prepend PGTrunk::CustomTypes
        # add migration methods
        ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.prepend PGTrunk::Statements
        # register those methods for migration directions
        ActiveRecord::Migration::CommandRecorder.include PGTrunk::CommandRecorder
        # support the registry table `pg_trunk` in addition to `schema_migrations`
        ActiveRecord::SchemaMigration.prepend PGTrunk::SchemaMigration
        # fix migration to enable different syntax without the name of the table
        ActiveRecord::Migration.prepend PGTrunk::Migration
        # make the migrator to remove stale records from `pg_trunk`
        ActiveRecord::Migrator.prepend PGTrunk::Migrator
      end
    end
  end
end
