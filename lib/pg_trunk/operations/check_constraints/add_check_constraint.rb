# frozen_string_literal: false

# @!parse
#   class ActiveRecord::Migration
#     # Add a check constraint to the table
#     #
#     # @param [#to_s] table (nil) The qualified name of the table
#     # @param [#to_s] expression (nil) The SQL expression
#     # @option [#to_s] :name (nil) The optional name of the constraint
#     # @option [Boolean] :inherit (true) If the constraint should be inherited by subtables
#     # @option [#to_s] :comment (nil) The comment describing the constraint
#     # @yield [c] the block with the constraint's definition
#     # @yieldparam Object receiver of methods specifying the constraint
#     # @return [void]
#     #
#     # The name of the new constraint can be set explicitly
#     #
#     #   add_check_constraint :users, "length(phone) > 10",
#     #                        name: "phone_is_long_enough",
#     #                        inherit: false,
#     #                        comment: "Phone is 10+ chars long"
#     #
#     # The name can also be skipped (it will be generated by default):
#     #
#     #   add_check_constraint :users, "length(phone) > 1"
#     #
#     # The block syntax can be used for any argument as usual:
#     #
#     #   add_check_constraint do |c|
#     #     c.table "users"
#     #     c.expression "length(phone) > 10"
#     #     c.name "phone_is_long_enough"
#     #     c.inherit false
#     #     c.comment "Phone is 10+ chars long"
#     #   end
#     #
#     # The operation is always reversible.
#     def add_check_constraint(table, expression = nil, **options, &block); end
#   end
module PGTrunk::Operations::CheckConstraints
  # @private
  class AddCheckConstraint < Base
    # The operation is used by the generator `rails g check_constraint`
    generates_object :check_constraint

    validates :expression, presence: true
    validates :if_exists, :new_name, :force, absence: true

    from_sql do
      <<~SQL
        SELECT
          c.oid,
          c.conname AS name,
          c.connamespace::regnamespace AS schema,
          r.relnamespace::regnamespace || '.' || r.relname AS "table",
          (
            NOT c.connoinherit
          ) AS inherit,
          (
            regexp_match(
              pg_get_constraintdef(c.oid),
              '^CHECK [(][(](.+)[)][)]( NO INHERIT)?$'
            )
          )[1] AS expression,
          d.description AS comment
        FROM pg_constraint c
          JOIN pg_class r ON r.oid = c.conrelid
          LEFT JOIN pg_description d ON c.oid = d.objoid
        WHERE c.contype = 'c';
      SQL
    end

    def to_sql(_version)
      [add_constraint, *add_comment, register_constraint].compact.join(" ")
    end

    def invert
      DropCheckConstraint.new(**to_h)
    end

    private

    def add_constraint
      sql = "ALTER TABLE #{table.to_sql} ADD CONSTRAINT #{name.name.inspect}"
      sql << " CHECK (#{expression})"
      sql << " NO INHERIT" unless inherit
      sql << ";"
    end

    def add_comment
      return if comment.blank?

      <<~SQL
        COMMENT ON CONSTRAINT #{name.lean.inspect} ON #{table.to_sql}
        IS $comment$#{comment}$comment$;
      SQL
    end

    # Rely on the fact the (schema.table, schema.name) is unique
    def register_constraint
      <<~SQL
        INSERT INTO pg_trunk (oid, classid)
          SELECT c.oid, 'pg_constraint'::regclass
          FROM pg_constraint c JOIN pg_class r ON r.oid = c.conrelid
          WHERE r.relname = #{table.quoted}
            AND r.relnamespace = #{table.namespace}
            AND c.conname = #{name.quoted}
        ON CONFLICT DO NOTHING;
      SQL
    end
  end
end