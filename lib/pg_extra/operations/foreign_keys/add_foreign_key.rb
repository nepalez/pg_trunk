# frozen_string_literal: false

# @!method ActiveRecord::Migration#add_foreign_key(table, reference, **options, &block)
# Create a foreign key constraint
#
# @param [#to_s] table (nil) The qualified name of the table
# @param [#to_s] reference (nil) The qualified name of the reference table
# @option [#to_s] :name (nil) The current name of the foreign key
# @option [#to_s] :to (nil) The new name for the foreign key
# @option [Array<#to_s>] :columns ([]) The list of columns of the table
# @option [#to_s] :column (nil) An alias for :columns for the case of single-column keys
# @option [Array<#to_s>] :primary_key ([]) The list of columns of the reference table
# @option [Symbol] :match (:full) Define how to match rows
#   Supported values: :full (default), :partial, :simple
# @option [Symbol] :on_delete (:restrict)
#   Define how to handle the deletion of the referred row.
#   Supported values: :restrict (default), :cascade, :nullify, :reset
# @option [Symbol] :on_update (:restrict)
#   Define how to handle the update of the referred row.
#   Supported values: :restrict (default), :cascade, :nullify, :reset
# @yield [Proc] the block with the key's definition
# @yieldparam The receiver of methods specifying the foreign key
#
# The table and reference of the new key must be set explicitly.
# All the rest (including the name) can be generated by default:
#
#   # same as `..., column: 'role_id', primary_key: 'id'`
#   add_foreign_key :users, :roles
#
# The block syntax can be used for any argument:
#
#   add_foreign_key do |c|
#     c.table "users"
#     c.reference "roles"
#     c.column "role_id" # (generated by default from reference and pk)
#     c.primary_key "id" # (default)
#     c.on_update :cascade # :restrict (default)
#     c.on_delete :cascade # :restrict (default)
#     c.name "user_roles_fk" # can be generated
#     c.comment "Phone is 10+ chars long"
#   end
#
# Composite foreign keys are supported as well:
#
#   add_foreign_key "users", "roles" do |c|
#     c.columns %w[role_name role_id]
#     c.primary_key %w[name id] # Requires unique index
#     c.match :full # :partial, :simple (default)
#   end
#
# The operation is always invertible.

module PGExtra::Operations::ForeignKeys
  # @private
  class AddForeignKey < Base
    # The operation used by the generator `rails g foreign_key`
    generates_object :foreign_key

    # New name is generated from the full signature
    # including table, reference, columns and primary_key.
    after_initialize { self.name = generated_name if name.blank? }

    validates :reference, presence: true
    validates :if_exists, :new_name, absence: true

    from_sql do
      <<~SQL
        SELECT
          c.oid,
          c.conname AS name,
          c.connamespace::regnamespace AS schema,
          (t.relnamespace::regnamespace || '.' || t.relname) AS "table",
          (r.relnamespace::regnamespace || '.' || r.relname) AS "reference",
          (
            SELECT array_agg(attname)
            FROM (
              SELECT a.attname
              FROM unnest(c.conkey) b(i) JOIN pg_attribute a ON a.attnum = b.i
              WHERE a.attrelid = c.conrelid
              ORDER BY array_position(c.conkey, b.i)
            ) list
          ) AS columns,
          (
            SELECT array_agg(attname)
            FROM (
              SELECT a.attname
              FROM unnest(c.confkey) b(i) JOIN pg_attribute a ON a.attnum = b.i
              WHERE a.attrelid = c.confrelid
              ORDER BY array_position(c.confkey, b.i)
            ) list
          ) AS primary_key,
          (
            CASE
              WHEN c.confupdtype = 'r' THEN 'restrict'
              WHEN c.confupdtype = 'c' THEN 'cascade'
              WHEN c.confupdtype = 'n' THEN 'nullify'
              WHEN c.confupdtype = 'd' THEN 'reset'
            END
          ) AS on_update,
          (
            CASE
              WHEN c.confdeltype = 'r' THEN 'restrict'
              WHEN c.confdeltype = 'c' THEN 'cascade'
              WHEN c.confdeltype = 'n' THEN 'nullify'
              WHEN c.confdeltype = 'd' THEN 'reset'
            END
          ) AS on_delete,
          (
            CASE
            WHEN c.confmatchtype = 's' THEN 'simple'
            WHEN c.confmatchtype = 'f' THEN 'full'
            WHEN c.confmatchtype = 'p' THEN 'partial'
            END
          ) AS match,
          c.convalidated AS validate,
          d.description AS comment
        FROM pg_constraint c
          JOIN pg_class t ON t.oid = c.conrelid
          JOIN pg_class r ON r.oid = c.confrelid
          LEFT JOIN pg_description d ON d.objoid = c.oid
        WHERE c.contype = 'f';
      SQL
    end

    def to_sql(_version)
      # Notice that in Rails the key `if_not_exists: true` means
      # the constraint should not be created if the table has ANY other
      # foreign key with the same reference <table>.
      return if if_not_exists && added?

      [add_constraint, create_comment, register_fk].join(" ")
    end

    def invert
      irreversible!("if_not_exists: true") if if_not_exists
      DropForeignKey.new(**to_h)
    end

    private

    def add_constraint
      sql = "ALTER TABLE #{table.to_sql} ADD CONSTRAINT #{name.lean.inspect}"
      sql << " FOREIGN KEY (#{columns.map(&:inspect).join(', ')})"
      sql << " REFERENCES #{reference.to_sql} (#{primary_key.map(&:inspect).join(', ')})"
      sql << " MATCH #{match.to_s.upcase}" if match&.!= :simple
      sql << " ON DELETE #{sql_action(on_delete)}"
      sql << " ON UPDATE #{sql_action(on_update)}"
      sql << " NOT VALID" unless validate
      sql << ";"
    end

    def create_comment
      return if comment.blank?

      <<~SQL
        COMMENT ON CONSTRAINT #{name.lean.inspect} ON #{table.to_sql}
        IS $comment$#{comment}$comment$;
      SQL
    end

    # Rely on the fact the (schema.table, schema.name) is unique
    def register_fk
      <<~SQL
        INSERT INTO pg_extra (oid, classid)
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