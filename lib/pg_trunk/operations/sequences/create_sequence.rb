# frozen_string_literal: false

# @!parse
#   class ActiveRecord::Migration
#     # Create a sequence
#     #
#     # @param [#to_s] name (nil) The qualified name of the sequence
#     # @option options [#to_s] :as ("bigint") The type of the sequence's value
#     #   Supported values: "bigint" (or "int8", default), "integer" (or "int4"), "smallint" ("int2").
#     # @option options [Boolean] :if_not_exists (false)
#     #   Suppress the error when the sequence already existed.
#     # @option options [Integer] :increment_by (1) Non-zero step of the sequence (either positive or negative).
#     # @option options [Integer] :min_value (nil) Minimum value of the sequence.
#     # @option options [Integer] :max_value (nil) Maximum value of the sequence.
#     # @option options [Integer] :start_with (nil) The first value of the sequence.
#     # @option options [Integer] :cache (1) The number of values to be generated and cached.
#     # @option options [Boolean] :cycle (false) If the sequence should be reset to start
#     #   after its value reaches min/max value.
#     # @option options [#to_s] :comment (nil) The comment describing the sequence.
#     # @yield [s] the block with the sequence's definition
#     # @yieldparam Object receiver of methods specifying the sequence
#     # @return [void]
#     #
#     # The sequence can be created by its qualified name only
#     #
#     # ```ruby
#     # create_sequence "my_schema.global_id"
#     # ```
#     #
#     # we also support all PostgreSQL settings for the sequence:
#     #
#     # ```ruby
#     # create_sequence "my_schema.global_id", as: "integer" do |s|
#     #   s.iterate_by 2
#     #   s.min_value 0
#     #   s.max_value 1999
#     #   s.start_with 1
#     #   s.cache 10
#     #   s.cycle true
#     #   s.comment "Global identifier"
#     # end
#     # ```
#     #
#     # Using a block method `s.owned_by` you can bind the sequence to
#     # some table's column. This means the sequence is dependent from
#     # the column and will be dropped along with it. Notice that the
#     # name of the table is NOT qualified because the table MUST belong
#     # to the same schema as the sequence itself.
#     #
#     # ```ruby
#     # create_table "users" do |t|
#     #   t.bigint :gid
#     # end
#     #
#     # create_sequence "my_schema.global_id" do |s|
#     #   s.owned_by "users", "gid"
#     # end
#     # ```
#     #
#     # With the `if_not_exists: true` option the operation wouldn't raise
#     # an exception in case the sequence has been already created.
#     #
#     # ```ruby
#     # create_sequence "my_schema.global_id", if_not_exists: true
#     # ```
#     #
#     # This option makes the migration irreversible due to uncertainty
#     # of the previous state of the database.
#     def create_sequence(name, **options, &block); end
#   end
module PGTrunk::Operations::Sequences
  # @private
  class CreateSequence < Base
    validates :if_exists, :force, :new_name, absence: true

    from_sql do |_server_version|
      <<~SQL
        SELECT
          c.oid,
          (c.relnamespace::regnamespace || '.' || c.relname) AS name,
          p.refobjid::regclass AS table,
          a.attname AS column,
          (
            CASE WHEN s.seqtypid != 'int8'::regtype THEN format_type(s.seqtypid, 0) END
          ) AS type,
          ( CASE WHEN s.seqincrement != 1 THEN s.seqincrement END ) AS increment_by,
          (
            CASE
            WHEN s.seqincrement > 0 THEN
              CASE WHEN s.seqmin != 1 THEN s.seqmin END
            ELSE
              CASE
              WHEN s.seqtypid = 'int2'::regtype AND s.seqmin = -32768 THEN NULL
              WHEN s.seqtypid = 'int4'::regtype AND s.seqmin = -2147483648 THEN NULL
              WHEN s.seqtypid = 'int8'::regtype AND s.seqmin = -9223372036854775808 THEN NULL
              ELSE s.seqmin
              END
            END
          ) AS min_value,
          (
            CASE
            WHEN s.seqincrement < 0 THEN
              CASE WHEN s.seqmax != -1 THEN s.seqmax END
            ELSE
              CASE
              WHEN s.seqtypid = 'int2'::regtype AND s.seqmax = 32767 THEN NULL
              WHEN s.seqtypid = 'int4'::regtype AND s.seqmax = 2147483647 THEN NULL
              WHEN s.seqtypid = 'int8'::regtype AND s.seqmax = 9223372036854775807 THEN NULL
              ELSE s.seqmax
              END
            END
          ) AS max_value,
          (
            CASE
            WHEN s.seqincrement > 0 AND s.seqstart = s.seqmin THEN NULL
            WHEN s.seqincrement < 0 AND s.seqstart = s.seqmax THEN NULL
            ELSE s.seqstart
            END
          ) AS start_with,
          ( CASE WHEN s.seqcache != 1 THEN s.seqcache END ) AS cache,
          ( CASE WHEN s.seqcycle THEN true END ) AS cycle,
          d.description AS comment
        FROM pg_sequence s
          JOIN pg_class c ON c.oid = s.seqrelid
          JOIN pg_trunk t ON t.oid = c.oid
            AND t.classid = 'pg_sequence'::regclass
          LEFT JOIN pg_depend p ON p.objid = c.oid
            AND p.classid = 'pg_class'::regclass
            AND p.refclassid = 'pg_class'::regclass
            AND p.objsubid = 0 AND p.refobjsubid !=0
          LEFT JOIN pg_attribute a ON a.attrelid = p.refobjid
            AND a.attnum = p.refobjsubid
          LEFT JOIN pg_description d ON d.objoid = c.oid;
      SQL
    end

    def to_sql(_server_version)
      [create_sequence, *comment_sequence, register_sequence].join(" ")
    end

    def invert
      irreversible!("if_not_exists: true") if if_not_exists
      DropSequence.new(**to_h.except(:if_not_exists))
    end

    private

    def create_sequence
      sql = "CREATE SEQUENCE"
      sql << " IF NOT EXISTS" if if_not_exists
      sql << " #{name.to_sql}"
      sql << " AS #{type}" if type.present?
      sql << " INCREMENT BY #{increment_by}" if increment_by.present?
      sql << " MINVALUE #{min_value}" if min_value.present?
      sql << " MAXVALUE #{max_value}" if max_value.present?
      sql << " START WITH #{start_with}" if start_with.present?
      sql << " CACHE #{cache}" if cache.present?
      sql << " OWNED BY #{table}.#{column}" if table.present? && column.present?
      sql << " CYCLE" if cycle
      sql << ";"
    end

    def comment_sequence
      <<~SQL.squish if comment.present?
        COMMENT ON SEQUENCE #{name.to_sql} IS $comment$#{comment}$comment$;
      SQL
    end

    def register_sequence
      <<~SQL.squish
        INSERT INTO pg_trunk (oid, classid)
          SELECT c.oid, 'pg_sequence'::regclass
          FROM pg_sequence s JOIN pg_class c ON c.oid = s.seqrelid
          WHERE c.relname = #{name.quoted}
            AND c.relnamespace = #{name.namespace}
        ON CONFLICT DO NOTHING;
      SQL
    end
  end
end
