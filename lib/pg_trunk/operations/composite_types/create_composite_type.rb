# frozen_string_literal: false

# @!method ActiveRecord::Migration#create_composite_type(name, **options, &block)
# Create a composite type
#
# @param [#to_s] name (nil) The qualified name of the type
# @option [#to_s] :comment (nil) The comment describing the constraint
# @yield [Proc] the block with the type's definition
# @yieldparam The receiver of methods specifying the type
#
# @example
#   create_composite_type "paint.colored_point" do |d|
#     d.column "x", "integer"
#     d.column "y", "integer"
#     d.column "color", "text", collation: "en_US"
#     d.comment <<~COMMENT
#       2D point with color
#     COMMENT
#   end
#
# It is always reversible.

module PGTrunk::Operations::CompositeTypes
  # @private
  class CreateCompositeType < Base
    validates :force, :if_exists, :new_name, absence: true

    from_sql do |_version|
      <<~SQL
        SELECT
          t.oid,
          (t.typnamespace::regnamespace || '.' || t.typname) AS name,
          (
            SELECT
              json_agg(
                json_build_object(
                  'name', a.attname,
                  'type', format_type(a.atttypid, a.atttypmod),
                  'collation', (
                    CASE
                    WHEN c.collnamespace != 'pg_catalog'::regnamespace
                      THEN c.collnamespace::regnamespace || '.' || c.collname
                    WHEN c.collname != 'default'
                      THEN c.collname
                    END
                  )
                ) ORDER BY a.attnum
              )
            FROM pg_attribute a
              LEFT JOIN pg_collation c ON c.oid = a.attcollation
            WHERE a.attrelid = t.typrelid
              AND EXISTS (SELECT FROM pg_type WHERE a.atttypid = pg_type.oid)
          ) AS columns,
          d.description AS comment
        FROM pg_type t
          JOIN pg_trunk e ON e.oid = t.oid
            AND e.classid = 'pg_type'::regclass
          LEFT JOIN pg_description d ON d.objoid = t.oid
            AND d.classoid = 'pg_type'::regclass
        WHERE t.typtype = 'c';
      SQL
    end

    def to_sql(_version)
      [create_type, *create_comment, register_type].join(" ")
    end

    def invert
      DropCompositeType.new(**to_h)
    end

    private

    def create_type
      <<~SQL.squish
        CREATE TYPE #{name.to_sql}
        AS (#{columns.reject(&:change).map(&:to_sql).join(',')});
      SQL
    end

    def create_comment
      return if comment.blank?

      "COMMENT ON TYPE #{name.to_sql} IS $comment$#{comment}$comment$;"
    end

    def register_type
      <<~SQL.squish
        INSERT INTO pg_trunk (oid, classid)
          SELECT oid, 'pg_type'::regclass
          FROM pg_type
          WHERE typname = #{name.quoted}
            AND typnamespace = #{name.namespace}
            AND typtype = 'c'
        ON CONFLICT DO NOTHING;
      SQL
    end
  end
end
