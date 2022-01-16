# frozen_string_literal: false

# @!parse
#   class ActiveRecord::Migration
#     # Drop a materialized view
#     #
#     # @param [#to_s] name (nil) The qualified name of the view
#     # @option options [Boolean] :if_exists (false) Suppress the error when the view is absent
#     # @option options [Symbol] :force (:restrict) How to process dependent objects (`:cascade` or `:restrict`)
#     # @option options [#to_s] :sql_definition (nil) The snippet containing the query
#     # @option options [#to_i] :revert_to_version (nil)
#     #   The alternative way to set sql_definition by referencing to a file containing the snippet
#     # @option options [#to_s] :tablespace (nil) The tablespace for the view
#     # @option options [Boolean] :with_data (true) If the view should be populated after creation
#     # @option options [#to_s] :comment (nil) The comment describing the view
#     # @yield [v] the block with the view's definition
#     # @yieldparam Object receiver of methods specifying the view
#     # @return [void]
#     #
#     # The operation drops a materialized view identified by its
#     # qualified name (it can include a schema).
#     #
#     # ```ruby
#     # drop_materialized_view "views.admin_users"
#     # ```
#     #
#     # To make the operation invertible, use the same options
#     # as in the `create_view` operation.
#     #
#     # ```ruby
#     # drop_materialized_view "views.admin_users" do |v|
#     #   v.sql_definition "SELECT name, password FROM users WHERE admin;"
#     #   v.column "password", storage: "external" # prevent compression
#     #   v.with_data false
#     #   v.comment "Admin users only"
#     # end
#     # ```
#     #
#     # You can also use a version-base SQL definition like:
#     #
#     # ```ruby
#     # drop_materialized_view "admin_users", revert_to_version: 1
#     # ```
#     #
#     # With the `force: :cascade` option the operation would remove
#     # all the objects which depend on the view.
#     #
#     # ```ruby
#     # drop_materialized_view "admin_users", force: :cascade
#     # ```
#     #
#     # With the `if_exists: true` option the operation won't fail
#     # even when the view was absent in the database.
#     #
#     # ```ruby
#     # drop_materialized_view "admin_users", if_exists: true
#     # ```
#     #
#     # Both options make a migration irreversible due to uncertainty
#     # of the previous state of the database.
#     def drop_materialized_view(name, **options, &block); end
#   end
module PGTrunk::Operations::MaterializedViews
  # @private
  class DropMaterializedView < Base
    # Forbid these attributes
    validates :algorithm, :cluster_on, :if_not_exists, :new_name, absence: true

    def to_sql(_version)
      sql = "DROP MATERIALIZED VIEW"
      sql << " IF EXISTS" if if_exists
      sql << " #{name.to_sql}"
      sql << " CASCADE" if force == :cascade
      sql << ";"
    end

    def invert
      irreversible!("if_exists: true") if if_exists
      irreversible!("force: :cascade") if force == :cascade
      CreateMaterializedView.new(**to_h.except(:force))
    end
  end
end
