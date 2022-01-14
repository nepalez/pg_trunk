# frozen_string_literal: false

# @!method ActiveRecord::Migration#validate_check_constraint(table, expression = nil, **options, &block)
# Validate an invalid check constraint
#
# @param [#to_s] table (nil) The qualified name of the table
# @param [#to_s] expression (nil) The SQL expression
# @option [#to_s] :name (nil) The optional name of the constraint
# @yield [Proc] the block with the constraint's definition
# @yieldparam The receiver of methods specifying the constraint
#
# The invalid constraint can be identified by table and explicit name:
#
#   validate_check_constraint :users, name: "phone_is_long_enough"
#
# Alternatively it can be specified by expression. In this case
# you must ensure the expression has the same form as it is stored
# in the database (after parsing the source).
#
#   validate_check_constraint :users, "length((phone::text) > 10)"
#
# Notice that it is invertible but the inverted operation does nothing.

module PGTrunk::Operations::CheckConstraints
  # @private
  class ValidateCheckConstraint < Base
    validates :if_exists, :force, :new_name, :comment, :new_name, :inherit,
              absence: true

    def to_sql(_version)
      <<~SQL.squish
        ALTER TABLE #{table.to_sql} VALIDATE CONSTRAINT #{name.name.inspect};
      SQL
    end

    # The operation is invertible but the inversion does nothing
    def invert; end
  end
end
