# frozen_string_literal: true

module PGExtra
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
      # @api private
      class Connection < SimpleDelegator
        include ActiveRecord::ConnectionAdapters::SchemaStatements

        def server_version
          raw_connection.server_version.to_s
        end
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
