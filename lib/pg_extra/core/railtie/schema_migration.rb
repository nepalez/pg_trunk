# frozen_string_literal: true

module PGExtra
  # The module makes `pg_extra` gem-specific registry
  # to be created and dropped along with the native schema.
  module SchemaMigration
    extend ActiveSupport::Concern

    class_methods do
      def create_table
        super
        PGExtra::Registry.create_table
      end

      def drop_table
        PGExtra::Registry.drop_table
        super
      end
    end
  end
end
