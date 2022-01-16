# frozen_string_literal: false

# @!parse
#   class ActiveRecord::Migration
#     # Change the name and/or schema of a composite type
#     #
#     # @param [#to_s] name (nil) The qualified name of the type
#     # @option [#to_s] :to (nil) The new qualified name for the type
#     # @return [void]
#     #
#     # ```ruby
#     # rename_composite_type "point", to: "paint.colored_point"
#     # ```
#     #
#     # The operation is always reversible.
#     def rename_composite_type(name, to:); end
#   end
module PGTrunk::Operations::CompositeTypes
  # @private
  class RenameCompositeType < Base
    validates :new_name, presence: true
    validates :force, :if_exists, :columns, absence: true

    def to_sql(_version)
      [*change_schema, *change_name].join("; ")
    end

    def invert
      self.class.new(**to_h, name: new_name, to: name)
    end

    private

    def change_schema
      return if name.schema == new_name.schema

      "ALTER TYPE #{name.to_sql} SET SCHEMA #{new_name.schema.inspect};"
    end

    def change_name
      return if new_name.name == name.name

      moved = name.merge(schema: new_name.schema)
      "ALTER TYPE #{moved.to_sql} RENAME TO #{new_name.name.inspect};"
    end
  end
end
