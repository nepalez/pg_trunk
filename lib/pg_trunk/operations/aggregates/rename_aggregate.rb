# frozen_string_literal: false

module PGTrunk::Operations::Aggregates
  #
  # Definition for the `rename_aggregate` operation
  #
  # A aggregate can be renamed by changing both the name
  # and the schema (namespace) it belongs to.
  #
  # If there are no overloaded aggregates, then you can use a plain name:
  #
  #   rename_aggregate "math.multiply", to: "public.product"
  #
  # otherwise the types of attributes must be explicitly specified.
  #
  #   rename_aggregate "math.multiply(int, int)", to: "public.product"
  #
  # Any specification of attributes or returned values in `to:` option
  # is ignored because they cannot be changed anyway.
  #
  # The operation is always reversible.
  #
  class RenameAggregate < Base
    validates :into, presence: true
    validate do
      next if into.blank? || name.blank?
      next if into.schema != name.schema
      next if into.routine != name.routine

      errors.add(:base, "Either the name or the schema must be changed")
    end
    # Forbid all attributes except for renaming
    (attribute_names.map(&:to_sym) - %i[name into]).each do |attr|
      validates attr, absence: true
    end

    def to_sql(_version)
      [*change_schema, *change_name].join("; ")
    end

    def invert
      q_into = "#{into.schema}.#{into.routine}(#{name.args}) #{name.returns}"
      self.class.new(**to_h, name: q_into.strip, to: name)
    end

    private

    def change_schema
      return if name.schema == into.schema

      "ALTER AGGREGATE #{name.to_sql} SET SCHEMA #{into.schema.inspect};"
    end

    def change_name
      return if into.routine == name.routine

      changed_name = name.merge(schema: into.schema).to_sql
      "ALTER AGGREGATE #{changed_name} RENAME TO #{into.routine.inspect};"
    end
  end
end
