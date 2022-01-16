# frozen_string_literal: false

# @!parse
#   class ActiveRecord::Migration
#     # Change the name and/or schema of a procedure
#     #
#     # @param [#to_s] :name (nil) The qualified name of the procedure
#     # @option [#to_s] :to (nil) The new qualified name for the procedure
#     # @return [void]
#     #
#     # A procedure can be renamed by changing both the name
#     # and the schema (namespace) it belongs to.
#     #
#     # If there are no overloaded procedures, then you can use a plain name:
#     #
#     # ```ruby
#     # rename_procedure "math.set_foo", to: "public.foo_setup"
#     # ```
#     #
#     # otherwise the types of attributes must be explicitly specified.
#     #
#     # ```ruby
#     # rename_procedure "math.set_foo(int)", to: "public.foo_setup"
#     # ```
#     #
#     # Any specification of attributes in `to:` option
#     # is ignored because they cannot be changed anyway.
#     #
#     # The operation is always reversible.
#     def rename_procedure(name, to:); end
#   end
module PGTrunk::Operations::Procedures
  # @private
  class RenameProcedure < Base
    validates :new_name, presence: true
    validates :body, :if_exists, :replace_existing, :language, :security, absence: true

    def to_sql(version)
      check_version!(version)

      [*change_schema, *change_name].join("; ")
    end

    def invert
      q_new_name = "#{new_name.schema}.#{new_name.routine}(#{name.args}) #{name.returns}"
      self.class.new(**to_h, name: q_new_name.strip, to: name)
    end

    private

    def change_schema
      return if name.schema == new_name.schema

      "ALTER PROCEDURE #{name.to_sql} SET SCHEMA #{new_name.schema.inspect};"
    end

    def change_name
      return if new_name.routine == name.routine

      changed_name = name.merge(schema: new_name.schema).to_sql
      "ALTER PROCEDURE #{changed_name} RENAME TO #{new_name.routine.inspect};"
    end
  end
end
