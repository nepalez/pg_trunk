# frozen_string_literal: false

# @!parse
#   class ActiveRecord::Migration
#     # Change the name and/or schema of a materialized view
#     #
#     # @param [#to_s] :name (nil) The qualified name of the view
#     # @option options [#to_s] :to (nil) The new qualified name for the view
#     # @option options [Boolean] :if_exists (false) Suppress the error when the view is absent
#     # @return [void]
#     #
#     # A materialized view can be renamed by changing both the name
#     # and the schema (namespace) it belongs to.
#     #
#     # ```ruby
#     # rename_materialized_view "views.admin_users", to: "admins"
#     # ```
#     #
#     # With the `if_exists: true` option, the operation won't fail
#     # even when the view wasn't existed.
#     #
#     # ```ruby
#     # rename_materialized_view "admin_users",
#     #                          to: "admins",
#     #                          if_exists: true
#     # ```
#     #
#     # At the same time, the option makes a migration irreversible
#     # due to uncertainty of the previous state of the database.
#     def rename_materialized_view(name, **options); end
#   end
module PGTrunk::Operations::MaterializedViews
  # @private
  class RenameMaterializedView < Base
    validates :new_name, presence: true
    validates :algorithm, :cluster_on, :columns, :force, :with_data, :comment,
              :if_not_exists, :sql_definition, :tablespace, :version,
              absence: true

    def to_sql(_version)
      [*change_schema, *change_name].join("; ")
    end

    def invert
      irreversible!("if_exists: true") if if_exists
      self.class.new(**to_h, name: new_name, to: name)
    end

    private

    def change_schema
      return if name.schema == new_name.schema

      sql = "ALTER MATERIALIZED VIEW"
      sql << " IF EXISTS" if if_exists
      sql << " #{name.to_sql} SET SCHEMA #{new_name.schema.inspect};"
    end

    def change_name
      return if new_name.name == name.name

      moved = name.merge(schema: new_name.schema)
      sql = "ALTER MATERIALIZED VIEW"
      sql << " IF EXISTS" if if_exists
      sql << " #{moved.to_sql} RENAME TO #{new_name.name.inspect};"
    end
  end
end
