# frozen_string_literal: false

# @!method ActiveRecord::Migration#rename_function(name, to:)
# Change the name and/or schema of a function
#
# @param [#to_s] :name (nil) The qualified name of the function
# @option [#to_s] :to (nil) The new qualified name for the function
#
# A function can be renamed by changing both the name
# and the schema (namespace) it belongs to.
#
# If there are no overloaded functions, then you can use a plain name:
#
#   rename_function "math.multiply", to: "public.product"
#
# otherwise the types of attributes must be explicitly specified.
#
#   rename_function "math.multiply(int, int)", to: "public.product"
#
# Any specification of attributes or returned values in `to:` option
# is ignored because they cannot be changed anyway.
#
# The operation is always reversible.

module PGExtra::Operations::Functions
  # @private
  class RenameFunction < Base
    validates :new_name, presence: true
    validates :body, :cost, :force, :if_exists, :language, :leakproof,
              :parallel, :replace_existing, :rows, :security, :strict,
              :volatility, absence: true

    def to_sql(_version)
      [*change_schema, *change_name].join(" ")
    end

    def invert
      q_new_name = "#{new_name.schema}.#{new_name.routine}(#{name.args}) #{name.returns}"
      self.class.new(**to_h, name: q_new_name.strip, to: name)
    end

    private

    def change_schema
      return if name.schema == new_name.schema

      "ALTER FUNCTION #{name.to_sql} SET SCHEMA #{new_name.schema.inspect};"
    end

    def change_name
      return if new_name.routine == name.routine

      changed_name = name.merge(schema: new_name.schema).to_sql
      "ALTER FUNCTION #{changed_name} RENAME TO #{new_name.routine.inspect};"
    end
  end
end
