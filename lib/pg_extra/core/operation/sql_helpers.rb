# frozen_string_literal: true

class PGExtra::Operation
  # Add helpers for building SQL queries
  module SQLHelpers
    extend ActiveSupport::Concern

    class_methods do
      include Enumerable

      # Get/set the block to extract operation definitions
      # from the database.
      # @yield [Proc] the block returning sql
      # @yieldparam [#to_s] version The current version of the database
      def from_sql(&block)
        @from_sql = block if block
        @from_sql ||= nil
      end

      # Iterate by sorted operation definitions
      # extracted from the database
      def each(&block)
        return to_enum unless block_given?

        fetch
          .map { |item| new(**item.symbolize_keys) }
          .sort
          .each { |op| block.call(op) }
      end

      private

      def fetch
        query = from_sql&.call(PGExtra.database.server_version)
        query.blank? ? [] : PGExtra.database.execute(query)
      end
    end

    def quote(str)
      PGExtra.database.quote(str)
    end
  end
end
