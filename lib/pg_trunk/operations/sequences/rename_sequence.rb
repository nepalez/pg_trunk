# frozen_string_literal: false

# @!parse
#   class ActiveRecord::Migration
#     # Rename a sequence
#     #
#     # @param [#to_s] name (nil) The current qualified name of the sequence
#     # @option options [#to_s] :to (nil) The new qualified name for the sequence
#     # @option options [Boolean] :if_exists (false) Suppress the error when the sequence is absent.
#     # @return [void]
#     #
#     # The operation allows to change both name and schema
#     #
#     # ```ruby
#     # rename_sequence "global_num", to: "sequences.global_number"
#     # ```
#     #
#     # With the `if_exists: true` option the operation wouldn't raise
#     # an exception in case the sequence hasn't been created yet.
#     #
#     # ```ruby
#     # create_sequence "my_schema.global_id", if_exists: true
#     # ```
#     #
#     # This option makes the migration irreversible due to uncertainty
#     # of the previous state of the database.
#     def rename_sequence(name, **options, &block); end
#   end
module PGTrunk::Operations::Sequences
  # @private
  class RenameSequence < Base
    validates :new_name, presence: true
    validates :if_not_exists, :force, :type, :increment_by, :min_value,
              :max_value, :start_with, :cache, :cycle, :comment, absence: true

    def to_sql(_version)
      [*change_schema, *change_name].join(" ")
    end

    def invert
      irreversible!("if_exists: true") if if_exists
      self.class.new(**to_h, name: new_name, to: name)
    end

    private

    def change_schema
      return if name.schema == new_name.schema

      sql = "ALTER SEQUENCE"
      sql << " IF EXISTS" if if_exists
      sql << " #{name.to_sql} SET SCHEMA #{new_name.schema.inspect};"
    end

    def change_name
      return if new_name.name == name.name

      moved = name.merge(schema: new_name.schema)
      sql = "ALTER SEQUENCE"
      sql << " IF EXISTS" if if_exists
      sql << " #{moved.to_sql} RENAME TO #{new_name.name.inspect};"
    end
  end
end
