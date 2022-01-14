# frozen_string_literal: false

# @!method ActiveRecord::Migration#create_view(name, **options, &block)
# Create a view
#
# @param [#to_s] name (nil) The qualified name of the view
# @option [Boolean] :replace_existing (false) If the view should overwrite an existing one
# @option [#to_s] :sql_definition (nil) The snippet containing the query
# @option [#to_i] :version (nil)
#   The alternative way to set sql_definition by referencing to a file containing the snippet
# @option [#to_s] :check (nil) Controls the behavior of automatically updatable views
#   Supported values: :local, :cascaded
# @option [#to_s] :comment (nil) The comment describing the view
# @yield [Proc] the block with the view's definition
# @yieldparam The receiver of methods specifying the view
#
# The operation creates the view using its `sql_definition`:
#
#   create_view("views.admin_users", sql_definition: <<~SQL)
#     SELECT id, name FROM users WHERE admin;
#   SQL
#
# For compatibility to the `scenic` gem, we also support
# adding a definition via its version:
#
#    create_view "admin_users", version: 1
#
# It is expected, that a `db/views/admin_users_v01.sql`
# to contain the SQL snippet.
#
# You can also set a comment describing the view, and the check option
# (either `:local` or `:cascaded`):
#
#   create_view "admin_users" do |v|
#     v.sql_definition "SELECT id, name FROM users WHERE admin;"
#     v.check :local
#     v.comment "Admin users only"
#   end
#
# With the `replace_existing: true` option the operation
# would use `CREATE OR REPLACE VIEW` command, so it
# can be used to "update" (or reload) the existing view.
#
#   create_view "admin_users", version: 1, replace_existing: true
#
# This option makes an operation irreversible due to uncertainty
# of the previous state of the database.

module PGTrunk::Operations::Views
  # @private
  class CreateView < Base
    validates :sql_definition, presence: true
    validates :if_exists, :force, :new_name, absence: true

    from_sql do |_version|
      <<~SQL
        SELECT
          c.oid,
          (c.relnamespace::regnamespace || '.' || c.relname) AS name,
          replace(pg_get_viewdef(c.oid, 60), ';', '') AS sql_definition,
          (
            SELECT option_value
            FROM pg_options_to_table(c.reloptions)
            WHERE option_name = 'check_option'
            LIMIT 1
          ) AS check,
          d.description AS comment
        FROM pg_class c
          JOIN pg_trunk e ON e.oid = c.oid
            AND e.classid = 'pg_class'::regclass
          LEFT JOIN pg_description d ON d.objoid = c.oid
            AND d.classoid = 'pg_class'::regclass
        WHERE c.relkind = 'v';
      SQL
    end

    def to_sql(_version)
      [create_view, *create_comment, register_view].join(" ")
    end

    def invert
      irreversible!("replace_existing: true") if replace_existing
      DropView.new(**to_h)
    end

    private

    def create_view
      sql = "CREATE"
      sql << " OR REPLACE" if replace_existing
      sql << " VIEW #{name.to_sql}"
      sql << " AS (#{sql_definition})"
      sql << " WITH #{check.to_s.upcase} CHECK OPTION" if check.present?
      sql << ";"
    end

    def create_comment
      return if comment.blank?

      "COMMENT ON VIEW #{name.to_sql} IS $comment$#{comment}$comment$;"
    end

    def register_view
      <<~SQL.squish
        INSERT INTO pg_trunk (oid, classid)
          SELECT oid, 'pg_class'::regclass
          FROM pg_class
          WHERE relname = #{name.quoted}
            AND relnamespace = #{name.namespace}
            AND relkind = 'v'
        ON CONFLICT DO NOTHING;
      SQL
    end
  end
end
