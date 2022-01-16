# frozen_string_literal: false

# @!parse
#   class ActiveRecord::Migration
#     # Change the name and/or schema of a domain type
#     #
#     # @param [#to_s] :name (nil) The qualified name of the type
#     # @option options [#to_s] :to (nil) The new qualified name for the type
#     # @return [void]
#     #
#     # A domain type can be both renamed and moved to another schema.
#     #
#     # ```ruby
#     # rename_domain "us_code", to: "dict.us_postal_code"
#     # ```
#     #
#     # The operation is always reversible.
#     def rename_domain(name, to:); end
#   end
module PGTrunk::Operations::Domains
  # @private
  class RenameDomain < Base
    validates :new_name, presence: true
    validates :force, :if_exists, absence: true

    def to_sql(_version)
      [*change_schema, *change_name].join("; ")
    end

    def invert
      self.class.new(**to_h, name: new_name, to: name)
    end

    private

    def change_schema
      return if name.schema == new_name.schema

      "ALTER DOMAIN #{name.to_sql} SET SCHEMA #{new_name.schema.inspect};"
    end

    def change_name
      return if new_name.name == name.name

      moved = name.merge(schema: new_name.schema)
      "ALTER DOMAIN #{moved.to_sql} RENAME TO #{new_name.name.inspect};"
    end
  end
end
