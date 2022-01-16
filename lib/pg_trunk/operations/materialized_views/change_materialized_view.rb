# frozen_string_literal: false

# @!parse
#   class ActiveRecord::Migration
#     # Modify a materialized view
#     #
#     # @param [#to_s] name (nil) The qualified name of the view
#     # @option [Boolean] :if_exists (false) Suppress the error when the view is absent
#     # @yield [v] the block with the view's definition
#     # @yieldparam Object receiver of methods specifying the view
#     # @return [void]
#     #
#     # The operation enables to alter a view without recreating
#     # its from scratch. You can rename columns, change their
#     # storage settings (how the column is TOAST-ed), or customize their statistics.
#     #
#     # ```ruby
#     # change_materialized_view "admin_users" do |v|
#     #   v.rename_column "name", to: "full_name"
#     #   v.column "name", storage: "extended", from_storage: "expanded"
#     #   v.column "admin", n_distinct: 2
#     #   v.column "role", statistics: 100
#     # end
#     # ```
#     #
#     # Notice that renaming will be done AFTER all changes even
#     # though the order of declarations can be different.
#     #
#     # As in the snippet above, to make the change invertible,
#     # you have to define a previous storage via `from_storage` option.
#     # The inversion would always reset statistics (set it to 0).
#     #
#     # In addition to changing columns, the operation enables
#     # to set a default clustering by given index:
#     #
#     # ```ruby
#     # change_materialized_view "admin_users" do |v|
#     #   v.cluster_on "admin_users_by_names_idx"
#     # end
#     # ```
#     #
#     # The clustering is invertible, but its inversion does nothing,
#     # keeping the clustering unchanged.
#     #
#     # The comment can also be changed:
#     #
#     # ```ruby
#     # change_materialized_view "admin_users" do |v|
#     #   v.comment "Admin users", from: "Admin users only"
#     # end
#     # ```
#     #
#     # Notice, that without `from` option the operation is still
#     # invertible, but its inversion would delete the comment.
#     # It can also be reset to the blank string explicitly:
#     #
#     # ```ruby
#     # change_materialized_view "admin_users" do |v|
#     #   v.comment "", from: "Admin users only"
#     # end
#     # ```
#     #
#     # With the `if_exists: true` option, the operation won't fail
#     # even when the view wasn't existed. At the same time,
#     # this option makes a migration irreversible due to uncertainty
#     # of the previous state of the database.
#     def change_materialized_view(name, **options, &block); end
#   end
module PGTrunk::Operations::MaterializedViews
  # @private
  class ChangeMaterializedView < Base
    # A method to be called in a block
    def rename_column(name, to:)
      columns << Column.new(name: name, new_name: to)
    end

    # Operation-specific validations
    validate { errors.add :base, "Changes can't be blank" if changes.blank? }
    validates :algorithm, :force, :if_not_exists, :new_name, :sql_definition,
              :tablespace, :version, :with_data, absence: true

    def to_sql(_version)
      [
        *change_columns,
        *rename_columns,
        *cluster_view,
        *update_comment,
      ].join(" ")
    end

    def invert
      irreversible!("if_exists: true") if if_exists
      undefined = inversion.select { |_, v| v.nil? }.keys.join(", ").presence
      raise IrreversibleMigration.new(self, nil, <<~MSG.squish) if undefined
        Undefined values to revert #{undefined}.
      MSG

      self.class.new(name: name, **inversion) if inversion.any?
    end

    private

    def changes
      @changes ||= {
        columns: columns.presence,
        cluster_on: cluster_on,
        comment: comment,
      }.compact
    end

    def inversion
      @inversion ||= {
        columns: columns.map(&:invert).presence,
        comment: from_comment,
      }.slice(*changes.keys)
    end

    def alter_view
      @alter_view ||= begin
        sql = "ALTER MATERIALIZED VIEW"
        sql << " IF EXISTS" if if_exists
        sql << " #{name.to_sql}"
      end
    end

    def change_columns
      changes = columns.reject(&:new_name).map(&:to_sql).join(", ")
      "#{alter_view} #{changes};" if changes.present?
    end

    def rename_columns
      changes = columns.select(&:new_name).map(&:to_sql).join(", ")
      "#{alter_view} #{changes};" if changes.present?
    end

    def cluster_view
      "#{alter_view} CLUSTER ON #{cluster_on.inspect};" if cluster_on.present?
    end

    def update_comment
      return if comment.nil?

      <<~SQL
        COMMENT ON MATERIALIZED VIEW #{name.to_sql}
        IS $comment$#{comment}$comment$;
      SQL
    end
  end
end
