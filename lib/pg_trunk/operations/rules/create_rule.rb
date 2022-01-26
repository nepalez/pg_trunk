# frozen_string_literal: false

# @!parse
#   class ActiveRecord::Migration
#     # Create a rule
#     #
#     # @param [#to_s] table (nil) The qualified name of the table
#     # @param [#to_s] name (nil) The name of the rule (unique within the table)
#     # @option options [Boolean] :replace_existing (false) If the rule should overwrite an existing one
#     # @option options [Symbol] :event (nil) The type of the query the rule is applied to.
#     #   Supported values: :update, :insert, :delete
#     # @option options [Symbol] :kind (:also) The kind of the rule (either :also or :instead).
#     #   In case of `instead` the original query wouldn't be executed, only the `command` is.
#     # @option options [String] :where (nil) The condition (SQL) for the rule to be applied.
#     # @option options [String] :command (nil) The SQL command to be added by the rule.
#     # @yield [r] the block with the rule's definition
#     # @yieldparam Object receiver of methods specifying the rule
#     # @return [void]
#     #
#     # @notice `SELECT` rules are not supported by the gem.
#     #
#     # To create a rule you must define table, and event (operation) for the rule.
#     # Usually you also supposed to define a command, but in case the `kind` is set
#     # to `:instead`, missing the command would provide `INSTEAD DO NOTHING` rule.
#     #
#     # ```ruby
#     # create_rule "users" do |r|
#     #   r.event :insert
#     #   r.kind :instead
#     #   r.comment "Forbid insertion to the table"
#     # SQL
#     # ```
#     #
#     # By default the kind is set to `:also`, in this case the `command` is needed as well:
#     #
#     # ```ruby
#     # create_rule "users", "_count_insertion" do |r|
#     #   r.event :insert
#     #   r.command <<~SQL
#     #     UPDATE counters SET user_inserts = user_inserts + 1
#     #   SQL
#     #   r.comment "Count insertion to the table"
#     # SQL
#     # ```
#     #
#     # With a `when` option you can also specify a condition:
#     #
#     # ```ruby
#     # create_rule "users", "_forbid_grants" do |r|
#     #   r.event :update
#     #   r.kind :instead
#     #   r.where "NOT old.admin AND new.admin"
#     #   r.comment "Forbid granting admin rights"
#     # SQL
#     # ```
#     #
#     # With a `replace_existing: true` option,
#     # the rule will be created using the `CREATE OR REPLACE` clause.
#     # In this case the migration is irreversible because we
#     # don't know if and how to restore the previous definition.
#     #
#     # ```ruby
#     # create_rule "users", "_forbid_insertion", replace_existing: true do |r|
#     #   r.event :insert
#     #   r.kind :instead
#     #   r.comment "Forbid insertion to the table"
#     # SQL
#     # ```
#     def create_rule(table, name = nil, **options, &block); end
#   end
module PGTrunk::Operations::Rules
  # @private
  class CreateRule < Base
    validates :if_exists, :force, :new_name, absence: true
    validates :event, presence: true
    validate do
      errors.add :command, :blank if kind != :instead && command.blank?
    end

    from_sql do |_server_version|
      <<~SQL
        SELECT
          r.oid,
          (c.relnamespace::regnamespace || '.' || c.relname) AS table,
          r.rulename AS name,
          (
            CASE
            WHEN r.ev_type = '1' THEN 'select'
            WHEN r.ev_type = '2' THEN 'update'
            WHEN r.ev_type = '3' THEN 'insert'
            WHEN r.ev_type = '4' THEN 'delete'
            END
          ) AS event,
          ( CASE WHEN r.is_instead THEN 'instead' ELSE 'also' END ) AS kind,
          pg_get_expr(r.ev_qual, r.oid, true) AS "where",
          regexp_replace(
            regexp_replace(
              pg_get_ruledef(r.oid, true),
              '.+ DO +(INSTEAD +)?(ALSO +)?(NOTHING *)?| *;',
              '',
              'g'
            ), '(\n|\s)+', ' ', 'g'
          ) AS command,
          d.description AS comment
        FROM pg_rewrite r
          JOIN pg_class c ON c.oid = r.ev_class
          JOIN pg_trunk t ON t.oid = r.oid
            AND t.classid = 'pg_rewrite'::regclass
          LEFT JOIN pg_description d ON d.objoid = r.oid
            AND d.classoid = 'pg_rewrite'::regclass
      SQL
    end

    def to_sql(_server_version)
      [create_rule, *comment_rule, register_rule].join(" ")
    end

    def invert
      irreversible!("replace_existing: true") if replace_existing
      DropRule.new(**to_h)
    end

    private

    def create_rule
      sql = "CREATE"
      sql << " OR REPLACE" if replace_existing
      sql << " RULE #{name.to_sql} AS ON #{event.to_s.upcase}"
      sql << " TO #{table.to_sql}"
      sql << " WHERE #{where}" if where.present?
      sql << " DO #{kind == :instead ? 'INSTEAD' : 'ALSO'}"
      sql << " #{command.presence || 'NOTHING'}"
      sql << ";"
    end

    def comment_rule
      <<~SQL.squish if comment.present?
        COMMENT ON RULE #{name.to_sql} ON #{table.to_sql}#{' '}
        IS $comment$#{comment}$comment$;
      SQL
    end

    def register_rule
      <<~SQL.squish
        INSERT INTO pg_trunk (oid, classid)
          SELECT r.oid, 'pg_rewrite'::regclass
          FROM pg_rewrite r JOIN pg_class c ON c.oid = r.ev_class
          WHERE r.rulename = #{name.quoted}
            AND c.relname = '#{table.name}'
            AND c.relnamespace = #{table.namespace}
        ON CONFLICT DO NOTHING;
      SQL
    end
  end
end
