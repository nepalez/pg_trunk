# frozen_string_literal: true

module PGExtra
  # @private
  # PGExtra database adapters.
  #
  # PGExtra ships with a Postgres adapter only,
  # with interface implemented as +PGExtra::Adapters::Postgres+.
  #
  module Adapters
    # Creates an instance of the PGExtra Postgres adapter.
    # This is the only supported adapter for PGExtra.
    #
    # @param [#connection] connectable An object that returns the connection
    #   for PGExtra to use. Defaults to `ActiveRecord::Base`.
    #
    class Postgres
      # Decorates an ActiveRecord connection with methods that help determine
      # the connections capabilities.
      #
      # Every attempt is made to use the versions of these methods defined by
      # Rails where they are available and public before falling back to our own
      # implementations for older Rails versions.
      #
      # @private
      class Connection < SimpleDelegator
        def server_version
          raw_connection.server_version.to_s
        end

        # Expose private method helpers

        def check_constraint_name(table, expression)
          __getobj__.send(
            :check_constraint_name,
            table,
            expression: expression,
          )
        end

        def strip_table_name(table)
          __getobj__.send(:strip_table_name_prefix_and_suffix, table)
        end
      end

      # Execute operation by its definition
      # @param [Class < PgExtra::Operation] operation
      def execute_operation(operation)
        query = operation.to_sql(server_version)
        connection.execute(query) if query
      end

      def dumper
        # This instance is used to dump the table
        # using its name extracted from the database.
        # That's why we can skip prefix/suffix definitions
        # in the parameters of the constructor.
        @dumper ||= connection.create_schema_dumper({})
      end

      private

      attr_reader :connectable

      def connection
        @connection ||= Connection.new(ActiveRecord::Base.connection)
      end

      def respond_to_missing?(symbol, *)
        connection.respond_to?(symbol, true)
      end

      def method_missing(symbol, *args, **opts, &block)
        super unless connection.respond_to?(symbol, true)

        connection.send(symbol, *args, **opts, &block)
      end
    end
  end
end
