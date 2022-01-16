# frozen_string_literal: false

# @!parse
#   class ActiveRecord::Migration
#     # Drop a domain type by qualified name
#     #
#     # @param [#to_s] name (nil) The qualified name of the type
#     # @option options [Boolean] :if_exists (false) Suppress the error when the type is absent
#     # @option options [Symbol] :force (:restrict) How to process dependent objects (`:cascade` or `:restrict`)
#     # @option options [#to_s] :as (nil) The base type for the domain (alias: :type)
#     # @option options [#to_s] :collation (nil) The collation
#     # @option options [#to_s] :default_sql (nil) The snippet for the default value of the domain
#     # @option options [#to_s] :comment (nil) The comment describing the constraint
#     # @yield [d] the block with the type's definition
#     # @yieldparam Object receiver of methods specifying the type
#     # @return [void]
#     #
#     # ```ruby
#     # drop_domain "dict.us_postal_code"
#     # ```
#     #
#     # To make the operation invertible, use the same options
#     # as in the `create_domain` operation.
#     #
#     # ```ruby
#     # drop_domain "dict.us_postal_code", as: "string" do |d|
#     #   d.constraint <<~SQL, name: "code_valid"
#     #     VALUE ~ '^\d{5}$' OR VALUE ~ '^\d{5}-\d{4}$'
#     #   SQL
#     #   d.comment <<~COMMENT
#     #     US postal code
#     #   COMMENT
#     # end
#     # ```
#     #
#     # With the `force: :cascade` option the operation would remove
#     # all the objects that use the type.
#     #
#     # ```ruby
#     # drop_domain "dict.us_postal_code", force: :cascade
#     # ```
#     #
#     # With the `if_exists: true` option the operation won't fail
#     # even when the view was absent in the database.
#     #
#     # ```ruby
#     # drop_domain "dict.us_postal_code", if_exists: true
#     # ```
#     #
#     # Both options make a migration irreversible due to uncertainty
#     # of the previous state of the database.
#     def drop_domain(name, **options, &block); end
#   end
module PGTrunk::Operations::Domains
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
