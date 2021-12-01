# frozen_string_literal: false

# @!method ActiveRecord::Migration#drop_check_constraint(table, expression = nil, **options, &block)
# Remove a check constraint from the table
#
# @param [#to_s] table (nil) The qualified name of the table
# @param [#to_s] expression (nil) The SQL expression
# @option [Boolean] :if_exists (false) Suppress the error when the constraint is absent
# @option [#to_s] :name (nil) The optional name of the constraint
# @option [Boolean] :inherit (true) If the constraint should be inherited by subtables
# @option [#to_s] :comment (nil) The comment describing the constraint
# @yield [Proc] the block with the constraint's definition
# @yieldparam The receiver of methods specifying the constraint
#
# Definition for the `drop_check_constraint` operation
#
# The constraint can be identified by the table and explicit name
#
#   drop_check_constraint :users, name: "phone_is_long_enough"
#
# Alternatively the name can be got from the expression.
# Be careful! the expression must have exactly the same form
# as stored in the database:
#
#   drop_check_constraint :users, "length((phone::text) > 10)"
#
# To made operation reversible the expression must be provided:
#
#   drop_check_constraint "users" do |c|
#     c.expression "length((phone::text) > 10)"
#     c.inherit false
#     c.comment "The phone is 10+ chars long"
#   end
#
# The operation can be called with `if_exists` option.
#
#   drop_check_constraint :users,
#                         name: "phone_is_long_enough",
#                         if_exists: true
#
# In this case the operation is always irreversible due to
# uncertainty of the previous state of the database.

module PGExtra::Operations::CheckConstraints
  # @private
  class DropCheckConstraint < Base
    validates :new_name, absence: true

    def to_sql(_version)
      sql = "ALTER TABLE #{table.to_sql} DROP CONSTRAINT"
      sql << " IF EXISTS" if if_exists
      sql << " #{name.name.inspect};"
    end

    def invert
      irreversible!("if_exists: true") if if_exists
      AddCheckConstraint.new(**to_h)
    end
  end
end
