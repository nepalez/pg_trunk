# frozen_string_literal: false

# @!parse
#   class ActiveRecord::Migration
#     # Create a domain type
#     #
#     # @param [#to_s] name (nil) The qualified name of the type
#     # @option [#to_s] :as (nil) The base type for the domain (alias: :type)
#     # @option [#to_s] :collation (nil) The collation
#     # @option [Boolean] :null (true) If a value of this type can be NULL
#     # @option [#to_s] :default_sql (nil) The snippet for the default value of the domain
#     # @option [#to_s] :comment (nil) The comment describing the constraint
#     # @yield [d] the block with the type's definition
#     # @yieldparam Object receiver of methods specifying the type
#     # @return [void]
#     #
#     # ```ruby
#     # create_domain "dict.us_postal_code", as: "text" do |d|
#     #   d.collation "en_US"
#     #   d.default_sql "'0000'::text"
#     #   d.null false
#     #   d.constraint <<~SQL, name: "code_valid"
#     #     VALUE ~ '^\d{5}$' OR VALUE ~ '^\d{5}-\d{4}$'
#     #   SQL
#     #   d.comment "US postal code"
#     # end
#     # ```
#     #
#     # It is always reversible.
#     def create_domain(name, **options, &block); end
#   end
module PGTrunk::Operations::Domains
  # @private
  class CreateDomain < Base
    validates :type, presence: true
    validates :force, :if_exists, :new_name, absence: true

    from_sql do |_version|
      <<~SQL
        SELECT
          t.oid,
          (t.typnamespace::regnamespace || '.' || t.typname) AS name,
          (
            CASE
            WHEN b.typnamespace != 'pg_catalog'::regnamespace
              THEN b.typnamespace::regnamespace || '.' || b.typname
            ELSE b.typname
            END
          ) AS "type",
          (
            CASE
            WHEN c.collnamespace != 'pg_catalog'::regnamespace
              THEN c.collnamespace::regnamespace || '.' || c.collname
            WHEN c.collname != 'default'
              THEN c.collname
            END
          ) AS collation,
          (CASE WHEN t.typnotnull THEN false END) AS null,
          (
            CASE
            WHEN t.typdefaultbin IS NOT NULL
            THEN pg_get_expr(t.typdefaultbin, 0, true)
            END
          ) AS default_sql,
          (
            SELECT json_agg(
              json_build_object(
                'name', c.conname,
                'check', pg_get_expr(c.conbin, 0, true)
              )
            )
            FROM pg_constraint c
            WHERE c.contypid = t.oid
          ) AS constraints,
          d.description AS comment
        FROM pg_type t
          JOIN pg_trunk e ON e.oid = t.oid
            AND e.classid = 'pg_type'::regclass
          JOIN pg_type b ON b.oid = t.typbasetype
          LEFT JOIN pg_collation c ON c.oid = t.typcollation
          LEFT JOIN pg_description d ON d.objoid = t.oid
            AND d.classoid = 'pg_type'::regclass
        WHERE t.typtype = 'd';
      SQL
    end

    def to_sql(_version)
      [create_domain, *create_comment, register_domain].join(" ")
    end

    def invert
      DropDomain.new(**to_h)
    end

    private

    def create_domain
      sql = "CREATE DOMAIN #{name.to_sql} AS #{type.to_sql}"
      sql << " COLLATE #{collation.to_sql}" if collation.present?
      sql << " DEFAULT #{default_sql}" if default_sql.present?
      sql << " NOT NULL" if null == false
      constraints&.each do |c|
        sql << " CONSTRAINT #{c.name.inspect}" if c.name.present?
        sql << " CHECK (#{c.check})"
      end
      sql << ";"
    end

    def create_comment
      return if comment.blank?

      "COMMENT ON DOMAIN #{name.to_sql} IS $comment$#{comment}$comment$;"
    end

    def register_domain
      <<~SQL.squish
        INSERT INTO pg_trunk (oid, classid)
          SELECT oid, 'pg_type'::regclass
          FROM pg_type
          WHERE typname = #{name.quoted}
            AND typnamespace = #{name.namespace}
            AND typtype = 'd'
        ON CONFLICT DO NOTHING;
      SQL
    end
  end
end
