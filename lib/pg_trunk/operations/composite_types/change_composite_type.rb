# frozen_string_literal: false

# @!parse
#   class ActiveRecord::Migration
#     # Modify a composite type
#     #
#     # @param [#to_s] name (nil) The qualified name of the type
#     # @option [Symbol] :force (:restrict) How to process dependent objects (`:cascade` or `:restrict`)
#     # @option [#to_s] :comment (nil) The comment describing the constraint
#     # @yield [t] the block with the type's definition
#     # @yieldparam Object receiver of methods specifying the type
#     # @return [void]
#     #
#     # The operation can be used to add, drop, rename or change columns.
#     # The comment can be changed as well.
#     #
#     # Providing a type "paint.colored_point":
#     #
#     #   create_composite_type "paint.colored_point" do |t|
#     #     t.column "color", "text", collation: "en_US"
#     #     t.column "x", "integer"
#     #     t.column "z", "integer"
#     #   end
#     #
#     # After the following change:
#     #
#     #   change_composite_type "paint.colored_point" do |t|
#     #     t.change_column "color", "text", collation: "ru_RU", from_collation: "en_US"
#     #     t.change_column "x", "bigint", from_type: "integer"
#     #     t.drop_column "z", "integer"
#     #     t.add_column "Y", "bigint"
#     #     t.rename_column "x", to: "X"
#     #     t.comment "2D point with a color", from: "2D point"
#     #   end
#     #
#     # The definition became:
#     #
#     #   create_composite_type "paint.colored_point" do |t|
#     #     t.column "color", "text", collation: "ru_RU"
#     #     t.column "X", "bigint"
#     #     t.column "Y", "integer"
#     #   end
#     #
#     # Notice, that all renames will be done AFTER other changes,
#     # so in `change_column` you should use the old names.
#     #
#     # In several cases the operation is not invertible:
#     #
#     # - when a column was dropped
#     # - when `force: :cascade` option is used (to update
#     #   objects that use the type)
#     # - when `if_exists: true` is added to the `drop_column` clause
#     # - when a previous state of the column type, collation or comment
#     #   is not specified.
#     def change_composite_type(name, **options, &block); end
#   end
module PGTrunk::Operations::CompositeTypes
  # @private
  class ChangeCompositeType < Base
    # Methods to populate `columns` from the block
    def add_column(name, type, collation: nil)
      columns << Column.new(
        name: name, type: type, collation: collation, change: :add, force: force,
      )
    end

    def drop_column(name, type = nil, **opts)
      opts = opts.slice(:if_exists, :collation)
      columns << Column.new(
        name: name, type: type, force: force, **opts, change: :drop,
      )
    end

    def change_column(name, type, **opts)
      opts = opts.slice(:collation, :from_type, :from_collation)
      columns << Column.new(
        name: name, type: type, force: force, change: :alter, **opts,
      )
    end

    def rename_column(name, to:)
      columns << Column.new(
        name: name, new_name: to, force: force, change: :rename,
      )
    end

    validates :if_exists, :new_name, absence: true
    validate { errors.add :base, "There are no changes" if change.blank? }

    def to_sql(_version)
      [*change_columns, *rename_columns, *change_comment].join(" ")
    end

    def invert
      keys = inversion.select { |_, v| v.nil? }.keys.join(", ").presence
      errors = columns.map(&:inversion_error).compact
      errors << "Can't invert #{keys}" if keys.present?
      errors << "Can't invert dropped columns" if columns.any? { |c| c.change == :drop }
      raise IrreversibleMigration.new(self, nil, *errors) if errors.any?

      self.class.new(**to_h, **inversion)
    end

    private

    def change_columns
      list = columns.select { |c| c.change&.!= :rename }
      return if list.blank?

      "ALTER TYPE #{name.to_sql} #{list.map(&:to_sql).join(', ')};"
    end

    def rename_columns
      columns.select { |c| c.change == :rename }.map do |c|
        "ALTER TYPE #{name.to_sql} #{c.to_sql};"
      end
    end

    def change_comment
      <<~SQL.squish if comment
        COMMENT ON TYPE #{name.to_sql} IS $comment$#{comment}$comment$;
      SQL
    end

    def change
      @change ||= {
        comment: comment,
        columns: columns.select(&:change).map(&:to_h).presence,
      }.compact
    end

    def inversion
      @inversion ||= {
        comment: from_comment,
        columns: columns.reverse.map(&:invert).presence,
      }.slice(*change.keys)
    end
  end
end
