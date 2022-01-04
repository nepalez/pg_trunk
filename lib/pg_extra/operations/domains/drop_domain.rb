# frozen_string_literal: false

# @!method ActiveRecord::Migration#drop_domain(name, **options, &block)
# Drop a domain type by qualified name
#
# @param [#to_s] name (nil) The qualified name of the type
# @option [Boolean] :if_exists (false) Suppress the error when the type is absent
# @option [Symbol] :force (:restrict) How to process dependent objects (`:cascade` or `:restrict`)
# @option [#to_s] :as (nil) The base type for the domain (alias: :type)
# @option [#to_s] :collation (nil) The collation
# @option [#to_s] :default_sql (nil) The snippet for the default value of the domain
# @option [#to_s] :comment (nil) The comment describing the constraint
# @yield [Proc] the block with the type's definition
# @yieldparam The receiver of methods specifying the type
#
# @example:
#
#   drop_domain "dict.us_postal_code"
#
# To make the operation invertible, use the same options
# as in the `create_domain` operation.
#
#   drop_domain "dict.us_postal_code", as: "string" do |d|
#     d.constraint <<~SQL, name: "code_valid"
#       VALUE ~ '^\d{5}$' OR VALUE ~ '^\d{5}-\d{4}$'
#     SQL
#     d.comment <<~COMMENT
#       US postal code
#     COMMENT
#   end
#
# With the `force: :cascade` option the operation would remove
# all the objects that use the type.
#
#   drop_domain "dict.us_postal_code", force: :cascade
#
# With the `if_exists: true` option the operation won't fail
# even when the view was absent in the database.
#
#   drop_domain "dict.us_postal_code", if_exists: true
#
# Both options make a migration irreversible due to uncertainty
# of the previous state of the database.

module PGExtra::Operations::Domains
  # @private
  class DropDomain < Base
    # Forbid these attributes
    validates :new_name, absence: true

    def to_sql(_version)
      sql = "DROP DOMAIN"
      sql << " IF EXISTS" if if_exists
      sql << " #{name.to_sql}"
      sql << " CASCADE" if force == :cascade
      sql << ";"
    end

    def invert
      irreversible!("if_exists: true") if if_exists
      irreversible!("force: :cascade") if force == :cascade
      CreateDomain.new(**to_h.except(:force))
    end
  end
end
