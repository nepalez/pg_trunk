# frozen_string_literal: false

# @!parse
#   class ActiveRecord::Migration
#     # Change the name and/or schema of a statistics
#     #
#     # @param [#to_s] :name (nil) The qualified name of the statistics
#     # @option [#to_s] :to (nil) The new qualified name for the statistics
#     # @return [void]
#     #
#     # A custom statistics can be renamed by changing both the name
#     # and the schema (namespace) it belongs to.
#     #
#     # ```ruby
#     # rename_statistics "math.my_stat", to: "public.my_stats"
#     # ```
#     #
#     # The operation is always reversible.
#     def rename_statistics(name, to:); end
#   end
module PGTrunk::Operations::Statistics
  # @private
  class RenameStatistics < Base
    after_initialize { self.new_name ||= generated_name }

    validates :new_name, presence: true
    validates :if_exists, :if_not_exists, :force, absence: true

    def to_sql(_version)
      [*change_schema, *change_name].join("; ")
    end

    def invert
      q_new_name = "#{new_name.schema}.#{new_name.routine}(#{name.args}) #{name.returns}"
      self.class.new(**to_h, name: q_new_name.strip, to: name)
    end

    private

    def change_schema
      return if name.schema == new_name.schema

      "ALTER STATISTICS #{name.to_sql} SET SCHEMA #{new_name.schema.inspect};"
    end

    def change_name
      return if new_name.routine == name.routine

      changed_name = name.merge(schema: new_name.schema).to_sql
      "ALTER STATISTICS #{changed_name} RENAME TO #{new_name.routine.inspect};"
    end
  end
end
