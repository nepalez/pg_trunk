# frozen_string_literal: false

# @!parse
#   class ActiveRecord::Migration
#     # Drop a composite type
#     #
#     # @param [#to_s] name (nil) The qualified name of the type
#     # @option options [Boolean] :if_exists (false) Suppress the error when the type is absent
#     # @option options [Symbol] :force (:restrict) How to process dependent objects (`:cascade` or `:restrict`)
#     # @option options [#to_s] :comment (nil) The comment describing the constraint
#     # @yield [t] the block with the type's definition
#     # @yieldparam Object receiver of methods specifying the type
#     # @return [void]
#     #
#     # The operation drops a composite_type type identified by its qualified name (it can include a schema).
#     #
#     # For inversion use the same options as in the `create_composite_type` operation.
#     #
#     # ```ruby
#     # drop_composite_type "paint.colored_point" do |d|
#     #   d.column "x", "integer"
#     #   d.column "y", "integer"
#     #   d.column "color", "text", collation: "en_US"
#     #   d.comment <<~COMMENT
#     #     2D point with color
#     #   COMMENT
#     # end
#     # ```
#     #
#     # Notice, that the composite type creation can use no attributes.
#     # That's why dropping it is always reversible; though the reversion provides a type without columns:
#     #
#     # ```ruby
#     # drop_composite_type "paint.colored_point"
#     # ```
#     #
#     # With the `force: :cascade` option the operation removes all objects using the type.
#     #
#     # ```ruby
#     # drop_composite_type "paint.colored_point", force: :cascade
#     # ```
#     #
#     # With the `if_exists: true` option the operation won't fail even when the view was absent.
#     #
#     # ```ruby
#     # drop_composite_type "paint.colored_point", if_exists: true
#     # ```
#     #
#     # Both options make a migration irreversible due to uncertainty of the previous state of the database.
#     def drop_composite_type(name, **options, &block); end
#   end
module PGTrunk::Operations::CompositeTypes
  # @private
  class DropCompositeType < Base
    # Forbid these columns
    validates :new_name, absence: true

    def to_sql(_version)
      sql = "DROP TYPE"
      sql << " IF EXISTS" if if_exists
      sql << " #{name.to_sql}"
      sql << " CASCADE" if force == :cascade
      sql << ";"
    end

    def invert
      irreversible!("if_exists: true") if if_exists
      irreversible!("force: :cascade") if force == :cascade
      CreateCompositeType.new(**to_h.except(:force, :if_exists))
    end
  end
end
