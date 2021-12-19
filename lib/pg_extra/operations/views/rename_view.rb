# frozen_string_literal: false

# @!method ActiveRecord::Migration#rename_view(name, **options)
# Change the name and/or schema of a view
#
# @param [#to_s] :name (nil) The qualified name of the view
# @option [#to_s] :to (nil) The new qualified name for the view
# @option [Boolean] :if_exists (false) Suppress the error when the view is absent
#
# A view can be renamed by changing both the name
# and the schema (namespace) it belongs to.
#
#   rename_view "views.admin_users", to: "admins"
#
# With the `if_exists: true` option, the operation won't fail
# even when the view wasn't existed.
#
#   rename_view "views.admin_users", to: "admins", if_exists: true
#
# At the same time, the option makes a view irreversible
# due to uncertainty of the previous state of the database.

module PGExtra::Operations::Views
  # @private
  class RenameView < Base
    validates :new_name, presence: true
    validates :replace_existing, :sql_definition, :check, :force, :version,
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

      sql = "ALTER VIEW"
      sql << " IF EXISTS" if if_exists
      sql << " #{name.to_sql} SET SCHEMA #{new_name.schema.inspect};"
    end

    def change_name
      return if new_name.name == name.name

      moved = name.merge(schema: new_name.schema)
      sql = "ALTER VIEW"
      sql << " IF EXISTS" if if_exists
      sql << " #{moved.to_sql} RENAME TO #{new_name.name.inspect};"
    end
  end
end
