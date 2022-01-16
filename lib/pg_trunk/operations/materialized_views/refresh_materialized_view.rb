# frozen_string_literal: false

# @!parse
#   class ActiveRecord::Migration
#     # Refresh a materialized view
#     #
#     # @param [#to_s] name (nil) The qualified name of the view
#     # @option options [Boolean] :with_data (true) If the view should be populated after creation
#     # @option options [Symbol] :algorithm (nil) Makes the operation concurrent when set to :concurrently
#     # @return [void]
#     #
#     # The operation enables refreshing a materialized view
#     # by reloading its underlying SQL query:
#     #
#     # ```ruby
#     # refresh_materialized_view "admin_users"
#     # ```
#     #
#     # The option `algorithm: :concurrently` acts exactly
#     # like in the `create_index` definition. You should
#     # possibly add the `disable_ddl_transaction!` command
#     # to the migration as well.
#     #
#     # With option `with_data: false` the command won't
#     # update the data. This option can't be used along with
#     # the `:algorithm`.
#     #
#     # The operation is always reversible, though its
#     # inversion does nothing.
#     def refresh_materialized_view(name, **options); end
#   end
module PGTrunk::Operations::MaterializedViews
  # @private
  class RefreshMaterializedView < Base
    validate do
      errors.add :algorithm, :present if with_data == false && algorithm
    end
    validates :cluster_on, :columns, :force, :if_exists, :if_not_exists,
              :new_name, :sql_definition, :tablespace, :version, :comment,
              absence: true

    def to_sql(_version)
      sql = "REFRESH MATERIALIZED VIEW"
      sql << " CONCURRENTLY" if algorithm == :concurrently
      sql << " #{name.to_sql}"
      sql << " WITH NO DATA" if with_data == false
      sql << ";"
    end

    # The operation is reversible but its inversion does nothing
    def invert; end
  end
end
