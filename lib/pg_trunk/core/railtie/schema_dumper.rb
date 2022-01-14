# frozen_string_literal: true

module PGTrunk
  # @private
  # Overloads methods defined in ActiveRecord::SchemaDumper
  # to redefine how various objects must be dumped.
  module SchemaDumper
    class << self
      def operations
        @operations ||= []
      end

      def register(operation)
        operations << operation unless operations.include?(operation)
      end
    end

    # Here we totally redefining the way a schema is dumped.
    #
    # In Rails every table definition is dumped as an `add_table`
    # creator including all its columns, indexes, type casts and foreign keys.
    #
    # In some circumstances, these objects can have inter-dependencies
    # with others (like functions, custom types and constraints).
    # For example, we could define a function getting table raw as an argument,
    # and then use this function to define check constraint for the table.
    # In this case we must insert the definition of the function between
    # the table's and constraint's ones.
    #
    # That's why we can neither rely on the method, defined in ActiveRecord
    # nor reuse it through fallback to `super` like both Scenic and F(x) do.
    # Instead of it, we fetch object definitions from the database,
    # and then resolve their inter-dependencies.
    def dump(stream)
      pg_trunk_register_custom_types
      header(stream)
      extensions(stream)
      pg_trunk_objects(stream)
      trailer(stream)
      stream
    end

    private

    # Before dumping the schema extract from SQL all custom types
    # to enable their usage in table columns in the schema.
    def pg_trunk_register_custom_types
      @connection.enable_pg_trunk_types
    end

    def pg_trunk_objects(stream)
      # Fetch operation definitions from the database.
      #
      # Operations of different kind are fetched
      # in the order of their definitions (see `lib/pg_trunk/definitions.rb`).
      # Operations of the same kind are sorted in a kind-specific order.
      operations = SchemaDumper.operations.flat_map(&:to_a)
      # Limit operations by oids known in `pg_trunk`
      oids = PGTrunk::Registry.pluck(:oid)
      operations = operations.select { |op| oids.include?(op.oid) }
      # Resolve dependencies between fetched commands.
      operations = PGTrunk::DependenciesResolver.resolve(operations)
      # provide the content of the schema.
      operations.each do |cmd|
        cmd.dump(stream)
        stream.puts
        stream.puts
      end
    end

    # Prevent indexes and check constraints from being added to the table
    def indexes_in_create(_table, _stream); end
    def check_constraints_in_create(_table, _stream); end
  end
end
