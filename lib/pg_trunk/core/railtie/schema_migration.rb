# frozen_string_literal: true

module PGTrunk
  # @private
  # The module makes `pg_trunk` gem-specific registry
  # to be created and dropped along with the native schema.
  module SchemaMigration
    extend ActiveSupport::Concern

    class_methods do
      def create_table
        super
        PGTrunk::Registry.create_table
      end

      def drop_table
        PGTrunk::Registry.drop_table
        super
      end
    end
  end
end
