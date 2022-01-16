# frozen_string_literal: false

# @!parse
#   class ActiveRecord::Migration
#     # Drop a view
#     #
#     # @param [#to_s] name (nil) The qualified name of the view
#     # @option [Boolean] :replace_existing (false) If the view should overwrite an existing one
#     # @option [Boolean] :if_exists (false) Suppress the error when the view is absent
#     # @option [Symbol] :force (:restrict) How to process dependent objects (`:cascade` or `:restrict`)
#     # @option [#to_s] :sql_definition (nil) The snippet containing the query
#     # @option [#to_i] :revert_to_version (nil)
#     #   The alternative way to set sql_definition by referencing to a file containing the snippet
#     # @option [#to_s] :check (nil) Controls the behavior of automatically updatable views
#     #   Supported values: :local, :cascaded
#     # @option [#to_s] :comment (nil) The comment describing the view
#     # @yield [v] the block with the view's definition
#     # @yieldparam Object receiver of methods specifying the view
#     # @return [void]
#     #
#     # The operation drops the existing view identified by its
#     # qualified name (it can include a schema).
#     #
#     #   drop_view "views.admin_users"
#     #
#     # To make the operation invertible, use the same options
#     # as in the `create_view` operation.
#     #
#     #   drop_view "views.admin_users" do |v|
#     #     v.sql_definition "SELECT name, email FROM users WHERE admin;"
#     #     v.check :local
#     #     v.comment "Admin users only"
#     #   end
#     #
#     # You can also use a version-base SQL definition like:
#     #
#     #    drop_view "views.admin_users", revert_to_version: 1
#     #
#     # With the `force: :cascade` option the operation would remove
#     # all the objects which depend on the view.
#     #
#     #   drop_view "views.admin_users", force: :cascade
#     #
#     # With the `if_exists: true` option the operation won't fail
#     # even when the view was absent in the database.
#     #
#     #   drop_view "views.admin_users", if_exists: true
#     #
#     # Both options make an operation irreversible due to uncertainty
#     # of the previous state of the database.
#     def drop_view(name, **options, &block); end
#   end
module PGTrunk::Operations::Views
  # @private
  class DropView < Base
    validates :replace_existing, :new_name, absence: true

    def to_sql(_version)
      sql = "DROP VIEW"
      sql << " IF EXISTS" if if_exists
      sql << " #{name.to_sql}"
      sql << " CASCADE" if force == :cascade
      sql << ";"
    end

    def invert
      irreversible!("if_exists: true") if if_exists
      irreversible!("force: :cascade") if force == :cascade
      CreateView.new(**to_h.except(:force))
    end
  end
end
