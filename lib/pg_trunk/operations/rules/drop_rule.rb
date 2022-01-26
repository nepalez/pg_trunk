# frozen_string_literal: false

# @!parse
#   class ActiveRecord::Migration
#     # Drop a rule
#     #
#     # @param [#to_s] table (nil) The qualified name of the table
#     # @param [#to_s] name (nil) The name of the rule (unique within the table)
#     # @option options [Boolean] :if_exists (false) Suppress the error when the rule is absent.
#     # @option options [Symbol] :force (:restrict) Define how to process dependent objects
#     #   Supported values: :restrict (default), :cascade (for cascade deletion)
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
#     # The rule can be identified by the table and explicit name
#     #
#     # ```ruby
#     # drop_rule :users, "_forbid_insertion"
#     # ```
#     #
#     # Alternatively the name can be got from kind and event.
#     #
#     # ```ruby
#     # drop_rule :users do |r|
#     #   r.event :insert
#     #   r.kind :instead
#     #   r.comment "Forbid insertion to the table"
#     # end
#     # ```
#     #
#     # To made operation reversible all the necessary parameters must be provided
#     # like in the `create_rule` operation:
#     #
#     # ```ruby
#     # drop_rule "users", "_count_insertion" do |r|
#     #   r.event :insert
#     #   r.command <<~SQL
#     #     UPDATE counters SET user_inserts = user_inserts + 1
#     #   SQL
#     #   r.comment "Count insertion to the table"
#     # SQL
#     # ```
#     #
#     # The operation can be called with `if_exists` option.
#     #
#     # ```ruby
#     # drop_rule :users, if_exists: true do |r|
#     #   # event and kind here are used to define a name
#     #   r.event :insert
#     #   r.kind :instead
#     # end
#     # ```
#     #
#     # With the `force: :cascade` option the operation would remove
#     # all the objects that use the rule.
#     #
#     # ```ruby
#     # drop_rule :users, force: :cascade do |r|
#     #   r.event :insert
#     #   r.kind :instead
#     # end
#     # ```
#     #
#     # In both cases the operation becomes irreversible due to
#     # uncertainty of the previous state of the database.
#     def drop_rule(table, name = nil, **options, &block); end
#   end
module PGTrunk::Operations::Rules
  # @private
  class DropRule < Base
    validates :replace_existing, :new_name, absence: true

    def to_sql(_version)
      sql = "DROP RULE"
      sql << " IF EXISTS" if if_exists
      sql << " #{name.name.inspect} ON #{table.to_sql}"
      sql << " CASCADE" if force == :cascade
      sql << ";"
    end

    def invert
      irreversible!("if_exists: true") if if_exists
      irreversible!("force: :cascade") if force == :cascade
      CreateRule.new(**to_h.except(:force))
    end
  end
end
