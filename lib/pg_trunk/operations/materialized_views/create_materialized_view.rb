# frozen_string_literal: false

# @!parse
#   class ActiveRecord::Migration
#     # Create a materialized view
#     #
#     # @param [#to_s] name (nil) The qualified name of the view
#     # @option [Boolean] :if_not_exists (false) Suppress the error when a view has been already created
#     # @option [#to_s] :sql_definition (nil) The snippet containing the query
#     # @option [#to_i] :version (nil)
#     #   The alternative way to set sql_definition by referencing to a file containing the snippet
#     # @option [#to_s] :tablespace (nil) The tablespace for the view
#     # @option [Boolean] :with_data (true) If the view should be populated after creation
#     # @option [#to_s] :comment (nil) The comment describing the view
#     # @yield [v] the block with the view's definition
#     # @yieldparam Object receiver of methods specifying the view
#     # @return [void]
#     #
#     # The operation creates the view using its `sql_definition`:
#     #
#     #   create_materialized_view("views.admin_users", sql_definition: <<~SQL)
#     #     SELECT id, name FROM users WHERE admin;
#     #   SQL
#     #
#     # For compatibility to the `scenic` gem, we also support
#     # adding a definition via its version:
#     #
#     #    create_materialized_view "admin_users", version: 1
#     #
#     # It is expected, that a `db/materialized_views/admin_users_v01.sql`
#     # to contain the SQL snippet.
#     #
#     # The tablespace can be specified for the created view.
#     # Notice that later it can't be changed (in PostgreSQL all rows
#     # can be moved to another tablespace, but we don't support
#     # this feature yet).
#     #
#     #   create_materialized_view "admin_users" do |v|
#     #     v.tablespace "fast_ssd"
#     #     v.sql_definition <<~SQL
#     #       SELECT id, name, password, admin, on_duty
#     #       FROM users
#     #       WHERE admin
#     #     SQL
#     #   end
#     #
#     # You can also set a comment describing the view,
#     # and redefine the storage options for some TOAST-ed columns,
#     # as well as their custom statistics:
#     #
#     #   create_materialized_view "admin_users" do |v|
#     #     v.sql_definition <<~SQL
#     #       SELECT id, name, password, admin, on_duty
#     #       FROM users
#     #       WHERE admin
#     #     SQL
#     #
#     #     v.column "password", storage: "external" # to avoid compression
#     #     v.column "password", n_distinct: -1 # linear dependency
#     #     v.column "admin", n_distinct: 1 # exact number of values
#     #     v.column "on_duty", statistics: 2 # the total number of values
#     #
#     #     v.comment "Admin users only"
#     #   end
#     #
#     # With the `replace_existing: true` option the operation
#     # would use `CREATE OR REPLACE VIEW` command, so it
#     # can be used to "update" (or reload) the existing view.
#     #
#     #   create_materialized_view "admin_users",
#     #                            version: 1,
#     #                            replace_existing: true
#     #
#     # This option makes the migration irreversible due to uncertainty
#     # of the previous state of the database.
#     def create_materialized_view(name, **options, &block); end
#   end
module PGTrunk::Operations::MaterializedViews
  # @private
  class CreateMaterializedView < Base
    validates :sql_definition, presence: true
    # Forbid these attributes
    validates :algorithm, :cluster_on, :force, :if_exists, :new_name, absence: true

    from_sql do |_version|
      <<~SQL
        SELECT
          c.oid,
          (c.relnamespace::regnamespace || '.' || c.relname) AS name,
          t.spcname AS "tablespace",
          replace(pg_get_viewdef(c.oid, 60), ';', '') AS sql_definition,
          (CASE WHEN NOT m.ispopulated THEN false END) AS with_data,
          (
            SELECT
              json_agg(
                json_build_object(
                  'name', a.attname,
                  'storage', (
                    CASE
                      WHEN a.attstorage = 'p' THEN 'plain'
                      WHEN a.attstorage = 'e' THEN 'external'
                      WHEN a.attstorage = 'x' THEN 'extended'
                      WHEN a.attstorage = 'm' THEN 'main'
                    END
                  )
                ) ORDER BY a.attnum
              )
            FROM pg_attribute a LEFT JOIN pg_type t ON t.oid = a.atttypid
            WHERE c.oid = a.attrelid AND t.typstorage != a.attstorage
          ) AS "columns",
          d.description AS comment
        FROM pg_class c
          JOIN pg_trunk e ON e.oid = c.oid AND e.classid = 'pg_class'::regclass
          JOIN pg_matviews m ON m.matviewname = c.relname
            AND m.schemaname::regnamespace = c.relnamespace::regnamespace
          LEFT JOIN pg_tablespace t ON t.oid = c.reltablespace
          LEFT JOIN pg_description d ON d.objoid = c.oid
            AND d.classoid = 'pg_class'::regclass
        WHERE c.relkind = 'm';
      SQL
    end

    def to_sql(_version)
      [create_view, *alter_columns, *create_comment, register_view].join(" ")
    end

    def invert
      irreversible!("if_not_exists: true") if if_not_exists
      DropMaterializedView.new(name: name)
    end

    private

    def create_view
      sql = "CREATE MATERIALIZED VIEW"
      sql << " IF NOT EXISTS" if if_not_exists
      sql << " #{name.to_sql}"
      sql << " TABLESPACE #{tablespace.inspect}" if tablespace.present?
      sql << " AS #{sql_definition}"
      sql << " WITH NO DATA" if with_data == false
      sql << ";"
    end

    def alter_columns
      return if columns.blank?

      sql = "ALTER MATERIALIZED VIEW #{name.to_sql}"
      sql << columns.flat_map(&:to_sql).join(", ")
      sql << ";"
    end

    def create_comment
      return if comment.blank?

      <<~SQL
        COMMENT ON MATERIALIZED VIEW #{name.to_sql}
        IS $comment$#{comment}$comment$;
      SQL
    end

    def register_view
      <<~SQL.squish
        INSERT INTO pg_trunk (oid, classid)
          SELECT oid, 'pg_class'::regclass
          FROM pg_class
          WHERE relname = #{name.quoted}
            AND relnamespace = #{name.namespace}
            AND relkind = 'm'
        ON CONFLICT DO NOTHING;
      SQL
    end
  end
end
