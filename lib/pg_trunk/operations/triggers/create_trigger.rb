# frozen_string_literal: false

# @!parse
#   class ActiveRecord::Migration
#     # Create a trigger for a table
#     #
#     # @param [#to_s] table (nil) The qualified name of the table
#     # @param [#to_s] name (nil) The name of the trigger
#     # @option [Boolean] :replace_existing (false) If the trigger should overwrite an existing one
#     # @option [#to_s] :function (nil) The qualified name of the function to be called
#     # @option [Symbol] :type (nil) When the trigger should be run
#     #   Supported values: :before, :after, :instead_of
#     # @option [Array<Symbol>] :events List of events running the trigger
#     #   Supported values in the array: :insert, :update, :delete, :truncate
#     # @option [Boolean] :constraint (false) If the trigger is a constraint
#     # @option [Symbol] :initially (:immediate) If the constraint check should be deferred
#     #   Supported values: :immediate (default), :deferred
#     # @option [#to_s] :when (nil) The SQL snippet definiing a condition for the trigger
#     # @option [Symbol] :for_each (:statement) Define if a trigger should be run for every row
#     #   Supported values: :statement (default), :row
#     # @option [#to_s] :comment (nil) The commend describing the trigger
#     # @yield [t] the block with the trigger's definition
#     # @yieldparam Object receiver of methods specifying the trigger
#     # @return [void]
#     #
#     # The trigger can be created either using inline syntax
#     #
#     #   create_trigger "users", "do_something",
#     #                   function: "do_something()",
#     #                   for_each: :row,
#     #                   type: :after,
#     #                   events: %i[insert update],
#     #                   comment: "Does something useful"
#     #
#     # or using a block:
#     #
#     #   create_trigger do |t|
#     #     t.table "users"
#     #     t.name "do_something"
#     #     t.function "do_something()"
#     #     t.for_each :row
#     #     t.type :after
#     #     t.events %i[insert update]
#     #     t.comment "Does something useful"
#     #   end
#     #
#     # With a `replace_existing: true` option,
#     # it will be created using the `CREATE OR REPLACE` clause.
#     # (Available in PostgreSQL v14+).
#     #
#     #    create_trigger "users", "do_something",
#     #                   function: "do_something()",
#     #                   type: :after,
#     #                   events: %i[insert update],
#     #                   replace_previous: true
#     #
#     # In this case the migration is irreversible because we
#     # don't know if and how to restore its previous definition.
#     def create_trigger(table, name = nil, **options, &block); end
#   end
module PGTrunk::Operations::Triggers
  # @private
  class CreateTrigger < Base
    validates :function, :type, :events, presence: true
    validates :if_exists, :new_name, absence: true

    from_sql do |_version|
      <<~SQL
        WITH t AS (
          SELECT
            t.oid,
            t.tgname AS name,
            (
              CASE WHEN t.tgconstraint != 0 THEN true END
            ) AS constraint,
            (
              CASE
                WHEN t.tgdeferrable AND t.tginitdeferred THEN 'deferred'
                WHEN t.tgdeferrable AND NOT t.tginitdeferred THEN 'immediate'
              END
            ) AS "initially",
            pg_get_triggerdef(t.oid, true) AS snippet,
            (
              CASE
              WHEN (t.tgtype::int::bit(7) & b'0000001')::int = 0 THEN 'statement'
              ELSE 'row'
              END
            ) AS for_each,
            (
              SELECT array_agg(attname)
              FROM (
                SELECT a.attname
                FROM unnest(t.tgattr) col(num)
                  JOIN pg_attribute a ON a.attnum = col.num
                WHERE a.attrelid = t.tgrelid
              ) list
            ) AS columns,
            (
              CASE
              WHEN ((tgtype::int::bit(7) & b'0000010')::int != 0) THEN 'before'
              WHEN ((tgtype::int::bit(7) & b'0000010')::int = 0) THEN 'after'
              ELSE 'instead_of'
              END
            ) AS type,
            array_remove(
              ARRAY[
                (CASE WHEN (tgtype::int::bit(7) & b'0000100')::int != 0 THEN 'insert' END),
                (CASE WHEN (tgtype::int::bit(7) & b'0001000')::int != 0 THEN 'delete' END),
                (CASE WHEN (tgtype::int::bit(7) & b'0010000')::int != 0 THEN 'update' END),
                (CASE WHEN (tgtype::int::bit(7) & b'0100000')::int != 0 THEN 'truncate' END)
              ]::text[],
              NULL
            ) AS events,
            (c.relnamespace::regnamespace || '.' || c.relname) AS "table",
            (f.pronamespace::regnamespace || '.' || f.proname || '()') AS function,
            d.description AS comment
          FROM pg_trigger t
            JOIN pg_proc f ON f.oid = t.tgfoid
            JOIN pg_class c ON c.oid = t.tgrelid
            LEFT JOIN pg_description d ON d.objoid = t.oid
        )
        SELECT
          oid,
          name,
          "table",
          function,
          "constraint",
          "initially",
          for_each,
          (
            CASE
            WHEN regexp_match(snippet, 'WHEN') IS NOT NULL
            THEN
              regexp_replace(
                regexp_replace(snippet, '^.+WHEN [(]', ''),
                '[)] EXECUTE.+',
                ''
              )
            END
          ) AS "when",
          type,
          events,
          columns,
          comment
        FROM t
      SQL
    end

    def to_sql(version)
      [
        create_trigger(version),
        *create_comment,
        register_trigger,
      ].join(" ")
    end

    def invert
      irreversible!("replace_existing: true") if replace_existing
      DropTrigger.new(**to_h)
    end

    private

    def create_trigger(version)
      sql = "CREATE"
      sql << " OR REPLACE" if replace_existing && version >= "14"
      sql << " CONSTRAINT" if constraint
      sql << " TRIGGER #{name.name.inspect}"
      sql << " BEFORE #{events_sql}" if type == :before
      sql << " AFTER #{events_sql}" if type == :after
      sql << " INSTEAD OF #{events_sql}" if type == :instead_of
      sql << " ON #{table.to_sql}"
      sql << " DEFERRABLE" if initially.present?
      sql << " INITIALLY DEFERRED" if initially == :deferred
      sql << " FOR EACH ROW" if for_each&.== :row
      sql << " WHEN (#{self.when})" if self.when.present?
      sql << " EXECUTE PROCEDURE #{function.to_sql(true)};"
    end

    def create_comment
      return unless comment

      <<~SQL.squish
        COMMENT ON TRIGGER #{name.name.inspect} ON #{table.to_sql}
          IS $comment$#{comment}$comment$;
      SQL
    end

    def register_trigger
      <<~SQL.squish
        INSERT INTO pg_trunk (oid, classid)
          SELECT t.oid, 'pg_trigger'::regclass
          FROM pg_trigger t JOIN pg_class c ON t.tgrelid = c.oid
          WHERE c.relname = #{table.quoted}
            AND c.relnamespace = #{table.namespace}
            AND t.tgname = #{name.quoted}
        ON CONFLICT DO NOTHING;
      SQL
    end

    def events_sql
      events.map do |event|
        if event == :update && columns.present?
          "UPDATE OF #{columns.join(', ')}"
        else
          event.to_s.upcase
        end
      end.join(" OR ")
    end
  end
end
