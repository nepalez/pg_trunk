# frozen_string_literal: false

# @!parse
#   class ActiveRecord::Migration
#     # Create an enumerated type by qualified name
#     #
#     # @param [#to_s] name (nil) The qualified name of the type
#     # @option options [Array<#to_s>] :values ([]) The list of values
#     # @option options [#to_s] :comment (nil) The comment describing the constraint
#     # @yield [e] the block with the type's definition
#     # @yieldparam Object receiver of methods specifying the type
#     # @return [void]
#     #
#     # ```ruby
#     # create_enum "finances.currency" do |e|
#     #   e.values "BTC", "EUR", "GBP", "USD"
#     #   e.value "JPY" # the alternative way to add a value to the tail
#     #   e.comment <<~COMMENT
#     #     The list of values for supported currencies.
#     #   COMMENT
#     # end
#     # ```
#     #
#     # It is always reversible.
#     def create_enum(name, **options, &block); end
#   end
module PGTrunk::Operations::Enums
  # @private
  class CreateEnum < Base
    validates :values, presence: true
    validates :changes, :force, :if_exists, :new_name, absence: true

    from_sql do |_version|
      <<~SQL
        SELECT
          t.oid,
          (t.typnamespace::regnamespace || '.' || t.typname) AS name,
          array_agg(n.enumlabel ORDER BY n.enumsortorder) AS values,
          d.description AS comment
        FROM pg_type t
          JOIN pg_trunk e ON e.oid = t.oid AND e.classid = 'pg_type'::regclass
          LEFT JOIN pg_enum n ON n.enumtypid = t.oid
          LEFT JOIN pg_description d ON d.objoid = t.oid
            AND d.classoid = 'pg_type'::regclass
        WHERE t.typtype = 'e'
        GROUP BY t.oid, t.typnamespace, t.typname, d.description
      SQL
    end

    def to_sql(_version)
      [create_enum, *create_comment, register_enum].join(" ")
    end

    def invert
      DropEnum.new(**to_h)
    end

    private

    def create_enum
      <<~SQL.squish
        CREATE TYPE #{name.to_sql} AS ENUM (
          #{values.map { |value| "'#{value}'" }.join(', ')}
        );
      SQL
    end

    def create_comment
      return if comment.blank?

      "COMMENT ON TYPE #{name.to_sql} IS $comment$#{comment}$comment$;"
    end

    def register_enum
      <<~SQL.squish
        INSERT INTO pg_trunk (oid, classid)
          SELECT oid, 'pg_type'::regclass
          FROM pg_type
          WHERE typname = #{name.quoted}
            AND typnamespace = #{name.namespace}
            AND typtype = 'e'
        ON CONFLICT DO NOTHING;
      SQL
    end
  end
end
