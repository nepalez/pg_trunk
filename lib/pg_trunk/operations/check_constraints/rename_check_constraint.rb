# frozen_string_literal: false

# @!parse
#   class ActiveRecord::Migration
#     # Rename a check constraint
#     #
#     # @param [#to_s] table (nil) The qualified name of the table
#     # @param [#to_s] expression (nil) The SQL expression
#     # @option [#to_s] :name (nil) The current name of the constraint
#     # @option [#to_s] :to (nil) The new name for the constraint
#     # @yield [c] the block with the constraint's definition
#     # @yieldparam Object receiver of methods specifying the constraint
#     # @return [void]
#     #
#     # A constraint can be identified by the table and explicit name
#     #
#     #   rename_check_constraint :users,
#     #                           name: "phone_is_long_enough",
#     #                           to: "phones.long_enough"
#     #
#     # Alternatively the name can be got from the expression.
#     # Be careful! the expression must have exactly the same form
#     # as stored in the database:
#     #
#     #   rename_check_constraint :users, "length((phone::text) > 10)",
#     #                           to: "long_enough"
#     #
#     # The name can be reset to auto-generated when
#     # the `:to` option is missed or blank:
#     #
#     #   rename_check_constraint :users, "phone_is_long_enough"
#     #
#     # The operation is always reversible.
#     def rename_check_constraint(table, expression = nil, **options, &block); end
#   end
module PGTrunk::Operations::CheckConstraints
  # @private
  class RenameCheckConstraint < Base
    # Reset the name to default when `to:` option is missed or set to `nil`
    after_initialize { self.new_name = generated_name if new_name.blank? }

    validates :new_name, presence: true
    validates :if_exists, :force, :comment, absence: true

    def to_sql(_version)
      <<~SQL.squish
        ALTER TABLE #{table.to_sql}
        RENAME CONSTRAINT #{name.name.inspect}
        TO #{new_name.name.inspect};
      SQL
    end

    def invert
      self.class.new(**to_h, name: new_name, to: name)
    end
  end
end
