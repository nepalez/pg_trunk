# frozen_string_literal: true

module PGTrunk
  # @private
  # The module adds custom type casting
  module CustomTypes
    # All custom types are typecasted to strings in Rails
    TYPE = ActiveRecord::ConnectionAdapters::PostgreSQL::OID::SpecializedString

    def self.known
      @known ||= Set.new([])
    end

    def enable_pg_trunk_types
      execute(<<~SQL).each { |item| enable_pg_trunk_type(**item.symbolize_keys) }
        SELECT (
          CASE
          WHEN t.typnamespace = 'public'::regnamespace THEN t.typname
          ELSE t.typnamespace::regnamespace || '.' || t.typname
          END
        ) AS name, t.oid
        FROM pg_trunk e JOIN pg_type t ON t.oid = e.oid
        WHERE e.classid = 'pg_type'::regclass
      SQL
    end

    def enable_pg_trunk_type(oid:, name:)
      CustomTypes.known << name
      type_map.register_type(oid.to_i, TYPE.new(name.to_s))
    end

    def valid_type?(type)
      CustomTypes.known.include?(type.to_s) || super
    end
  end
end
