# frozen_string_literal: true

module PGTrunk
  # @private
  # The internal model to represent the gem-specific registry
  # where we store information about objects added by migrations.
  #
  # Every time when an object is created, we should record it
  # in the table, setting its `oid` along with the reference
  # to the system table (`classid::oid`).
  #
  # The third column `version::text` keeps the current version
  # where the object has been added.
  #
  # rubocop: disable Metrics/ClassLength
  class Registry < ActiveRecord::Base
    class << self
      def _internal?
        true
      end

      def primary_key
        "oid"
      end

      def table_name
        "pg_trunk"
      end

      # rubocop: disable Metrics/MethodLength
      def create_table
        return if connection.table_exists?(table_name)

        connection.create_table(
          table_name,
          id: false,
          if_not_exists: true,
          comment: "Objects added by migrations",
        ) do |t|
          t.column :oid, :oid, primary_key: true, comment: "Object identifier"
          t.column :classid, :oid, null: false, comment: \
                   "ID of the systems catalog in pg_class"
          t.column :version, :string, index: true, comment: \
                   "Version of the migration that added the object"
          t.foreign_key ActiveRecord::Base.schema_migrations_table_name,
                        column: :version, primary_key: :version,
                        on_update: :cascade, on_delete: :cascade
        end
      end
      # rubocop: enable Metrics/MethodLength

      # This method is called by a migrator after applying
      # all migrations in whatever direction.
      def finalize
        connection.execute [
          *create_table,
          *forget_dropped_objects,
          *remember_tables,
          *fill_missed_version,
        ].join(";")
      end

      def drop_table
        connection.drop_table table_name, if_exists: true
      end

      private

      # List of service tables that shouldn't get into the registry.
      SERVICE_TABLES = [
        ActiveRecord::Base.schema_migrations_table_name,
        ActiveRecord::Base.internal_metadata_table_name,
        "pg_trunk",
      ].freeze

      def catalogs
        connection
          .execute("SELECT DISTINCT classid::regclass FROM #{table_name}")
          .map { |item| item["classid"] }
      end

      # Delete all objects which are absent in system catalogs
      # (they could be deleted either explicitly, or through
      # the cascade dependencies clearance).
      def forget_dropped_objects
        catalogs.map do |tbl|
          <<~SQL.squish
            DELETE FROM #{table_name}
            WHERE classid = '#{tbl}'::regclass
              AND oid NOT IN (SELECT oid FROM #{tbl});
          SQL
        end
      end

      # Register all tables known to Rails
      # along with their indexes, check constraints and foreign keys.
      # This would let us fetch those objects even though
      # they were created by native methods of +ActiveRecord+ like
      # `create_table` etc.
      def remember_tables
        names_and_schemas = names_and_schemas_sql
        return unless names_and_schemas

        <<~SQL.squish
          WITH
            tbl AS (
              SELECT oid FROM pg_class
              WHERE #{names_and_schemas} AND relkind IN ('r', 'p')
            ),
            idx AS (
              SELECT r.oid
              FROM pg_class r
              JOIN pg_index i ON r.oid = i.indexrelid
              JOIN tbl ON i.indrelid = tbl.oid
            ),
            con AS (
              SELECT c.oid AS oid
              FROM pg_constraint c
              JOIN tbl ON c.conrelid = tbl.oid
              WHERE c.contype IN ('c', 'f')
            ),
            obj (oid, classid) AS (
              SELECT oid, 'pg_class'::regclass FROM tbl
              UNION
              SELECT oid, 'pg_class'::regclass FROM idx
              UNION
              SELECT oid, 'pg_constraint'::regclass FROM con
            )
          INSERT INTO #{table_name} (oid, classid)
          SELECT oid, classid FROM obj
          ON CONFLICT DO NOTHING;
        SQL
      end

      # Assign the most recent version to new records in `pg_trunk`.
      def fill_missed_version
        <<~SQL
          UPDATE #{table_name} SET version = list.version
          FROM (
            SELECT max(version) AS version
            FROM "#{ActiveRecord::Base.schema_migrations_table_name}"
          ) list
          WHERE #{table_name}.version IS NULL;
        SQL
      end

      def names_and_schemas_sql
        (connection.tables - SERVICE_TABLES)
          .map { |table| QualifiedName.wrap(table) }
          .group_by(&:namespace)
          .transform_values { |list| list.map(&:quoted).join(",") }
          .map { |nsp, tbl| "relnamespace = #{nsp} AND relname IN (#{tbl})" }
          .join("OR")
          .presence
      end
    end
  end
  # rubocop: enable Metrics/ClassLength
end
