# frozen_string_literal: false

# @!method ActiveRecord::Migration#drop_enum(name, **options, &block)
# Drop an enumerated type by qualified name
#
# @param [#to_s] name (nil) The qualified name of the type
# @option [Boolean] :if_exists (false) Suppress the error when the type is absent
# @option [Symbol] :force (:restrict) How to process dependent objects (`:cascade` or `:restrict`)
# @option [Array<#to_s>] :values ([]) The list of values
# @option [#to_s] :comment (nil) The comment describing the constraint
# @yield [Proc] the block with the type's definition
# @yieldparam The receiver of methods specifying the type
#
# The operation drops a enumerated type identified by its
# qualified name (it can include a schema).
#
#   drop_enum "finances.currency"
#
# To make the operation invertible, use the same options
# as in the `create_enum` operation.
#
#   drop_enum "finances.currency" do |e|
#     e.values "BTC", "EUR", "GBP", "USD"
#     e.value "JPY" # the alternative way to add a value
#     e.comment <<~COMMENT
#       The list of values for supported currencies.
#     COMMENT
#   end
#
# With the `force: :cascade` option the operation would remove
# all the objects that use the type.
#
#   drop_enum "finances.currency", force: :cascade
#
# With the `if_exists: true` option the operation won't fail
# even when the view was absent in the database.
#
#   drop_enum "finances.currency", if_exists: true
#
# Both options make a migration irreversible due to uncertainty
# of the previous state of the database.

module PGExtra::Operations::Enums
  # @private
  class DropEnum < Base
    # Forbid these attributes
    validates :changes, :new_name, absence: true

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
      CreateEnum.new(**to_h.except(:force))
    end
  end
end
