# frozen_string_literal: false

# @!parse
#   class ActiveRecord::Migration
#     # Create a custom statistics
#     #
#     # @param [#to_s] name (nil) The qualified name of the statistics
#     # @option options [Boolean] :if_not_exists (false)
#     #   Suppress the error when the statistics is already exist
#     # @option options [#to_s] table (nil)
#     #   The qualified name of the table whose statistics will be collected
#     # @option options [Array<Symbol>] kinds ([:dependencies, :mcv, :ndistinct])
#     #   The kinds of statistics to be collected (all by default).
#     #   Supported values in the array: :dependencies, :mcv, :ndistinct
#     # @option options [#to_s] :comment The description of the statistics
#     # @yield [s] the block with the statistics' definition
#     # @yieldparam Object receiver of methods specifying the statistics
#     # @return [void]
#     #
#     # The statistics can be created with explicit name:
#     #
#     # ```ruby
#     # create_statistics "users_stats" do |s|
#     #   s.table "users"
#     #   s.columns "family", "name"
#     #   s.kinds :dependencies, :mcv, :ndistinct
#     #   s.comment "Statistics for users' names and families"
#     # SQL
#     # ```
#     #
#     # The name can be generated as well:
#     #
#     # ```ruby
#     # create_statistics do |s|
#     #   s.table "users"
#     #   s.columns "family", "name"
#     #   s.kinds :dependencies, :mcv, :ndistinct
#     #   s.comment "Statistics for users' names and families"
#     # SQL
#     # ```
#     #
#     # Since v14 PostgreSQL have supported expressions in addition to columns:
#     #
#     # ```ruby
#     # create_statistics "users_stats" do |s|
#     #   s.table "users"
#     #   s.columns "family"
#     #   s.expression "length(name)"
#     #   s.kinds :dependencies, :mcv, :ndistinct
#     #   s.comment "Statistics for users' name lengths and families"
#     # SQL
#     # ```
#     #
#     # as well as statistics for the sole expression (kinds must be blank)
#     # by columns of some table.
#     #
#     # ```ruby
#     # create_statistics "users_stats" do |s|
#     #   s.table "users"
#     #   s.expression "length(name || ' ' || family)"
#     #   s.comment "Statistics for full name lengths"
#     # SQL
#     # ```
#     #
#     # Use `if_not_exists: true` to suppress error in case the statistics
#     # has already been created. This option, though, makes the migration
#     # irreversible due to uncertainty of the previous state of the database.
#     def create_statistics(name, **options, &block); end
#   end
module PGTrunk::Operations::Statistics
  # SQL snippet to fetch statistics in v10-13
  SQL_V10 = <<~SQL.freeze
    WITH
      list (key, name) AS (
        VALUES ('m', 'mcv'), ('f', 'dependencies'), ('d', 'ndistinct')
      )
    SELECT
      s.oid,
      (s.stxnamespace::regnamespace || '.' || s.stxname) AS name,
      (t.relnamespace::regnamespace || '.' || t.relname) AS "table",
      (
        SELECT array_agg(l.name)
        FROM list l
        WHERE ARRAY[l.key]::char[] <@ s.stxkind::char[]
      ) AS kinds,
      (
        SELECT array_agg(DISTINCT a.attname)
        FROM pg_attribute a
        WHERE a.attrelid = s.stxrelid
          AND ARRAY[a.attnum]::int[] <@ s.stxkeys::int[]
      ) AS columns,
      d.description AS comment
    FROM pg_statistic_ext s
      JOIN pg_trunk e ON e.oid = s.oid AND e.classid = 'pg_statistic_ext'::regclass
      JOIN pg_class t ON t.oid = s.stxrelid
      LEFT JOIN pg_description d ON d.objoid = s.oid;
  SQL

  # In version 14 statistics can be collected for expressions.
  SQL_V14 = <<~SQL.freeze
    WITH
      list (key, name) AS (
        VALUES ('m', 'mcv'), ('f', 'dependencies'), ('d', 'ndistinct')
      )
    SELECT
      s.oid,
      (s.stxnamespace::regnamespace || '.' || s.stxname) AS name,
      (t.relnamespace::regnamespace || '.' || t.relname) AS "table",
      (
        SELECT array_agg(l.name)
        FROM list l
        WHERE ARRAY[l.key]::char[] <@ s.stxkind::char[]
      ) AS kinds,
      (
        SELECT array_agg(DISTINCT a.attname)
        FROM pg_attribute a
        WHERE a.attrelid = s.stxrelid
          AND ARRAY[a.attnum]::int[] <@ s.stxkeys::int[]
      ) AS columns,
      pg_get_expr(s.stxexprs, stxrelid, true) AS expressions,
      d.description AS comment
    FROM pg_statistic_ext s
      JOIN pg_trunk e ON e.oid = s.oid AND e.classid = 'pg_statistic_ext'::regclass
      JOIN pg_class t ON t.oid = s.stxrelid
      LEFT JOIN pg_description d ON d.objoid = s.oid;
  SQL

  # @private
  class CreateStatistics < Base
    validates :if_exists, :force, :new_name, absence: true
    validates :table, presence: true
    validate do
      errors.add :base, "Columns and expressions can't be blank" if parts.blank?
    end

    from_sql do |version|
      version >= "14" ? SQL_V14 : SQL_V10
    end

    def to_sql(version)
      check_version!(version)

      [create_statistics, *create_comment, register_object].join(" ")
    end

    def invert
      irreversible!("if_not_exists: true") if if_not_exists
      DropStatistics.new(**to_h)
    end

    private

    def check_version!(version)
      raise <<~ERROR.squish if version < "14" && expressions.present?
        Statistics for expressions are supported in PostgreSQL v14+"
      ERROR

      raise <<~ERROR.squish if version < "12" && kinds.include?(:mcv)
        The `mcv` kind is supported in PostgreSQL v12+
      ERROR
    end

    def create_statistics
      sql = "CREATE STATISTICS"
      sql << " IF NOT EXISTS" if if_not_exists
      sql << " #{name.to_sql}"
      sql << " (#{kinds.join(',')})" if kinds.present?
      sql << " ON #{parts.join(', ')}"
      sql << "FROM #{table.to_sql};"
    end

    def create_comment
      return if comment.blank?

      "COMMENT ON STATISTICS #{name.to_sql} IS $comment$#{comment}$comment$;"
    end

    def register_object
      <<~SQL
        INSERT INTO pg_trunk(oid, classid)
        SELECT s.oid, 'pg_statistic_ext'::regclass
        FROM pg_statistic_ext s
          JOIN pg_class t ON t.oid = s.stxrelid
        WHERE s.stxname = #{name.quoted}
          AND s.stxnamespace = #{name.namespace}
          AND t.relname = #{table.quoted}
          AND t.relnamespace = #{table.namespace}
        ON CONFLICT DO NOTHING;
      SQL
    end
  end
end
