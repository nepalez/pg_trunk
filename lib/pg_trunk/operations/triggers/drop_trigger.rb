# frozen_string_literal: false

# @!parse
#   class ActiveRecord::Migration
#     # Drop a trigger for a table
#     #
#     # @param [#to_s] table (nil) The qualified name of the table
#     # @param [#to_s] name (nil) The name of the trigger
#     # @option options [Boolean] :if_exists (false) Suppress the error when the trigger is absent
#     # @option options [#to_s] :function (nil) The qualified name of the function to be called
#     # @option options [Symbol] :type (nil) When the trigger should be run
#     #   Supported values: :before, :after, :instead_of
#     # @option options [Array<Symbol>] :events List of events running the trigger
#     #   Supported values in the array: :insert, :update, :delete, :truncate
#     # @option options [Boolean] :constraint (false) If the trigger is a constraint
#     # @option options [Symbol] :initially (:immediate) If the constraint check should be deferred
#     #   Supported values: :immediate (default), :deferred
#     # @option options [#to_s] :when (nil) The SQL snippet definiing a condition for the trigger
#     # @option options [Symbol] :for_each (:statement) Define if a trigger should be run for every row
#     #   Supported values: :statement (default), :row
#     # @option options [#to_s] :comment (nil) The commend describing the trigger
#     # @yield [t] the block with the trigger's definition
#     # @yieldparam Object receiver of methods specifying the trigger
#     # @return [void]
#     #
#     # A trigger can be dropped by a table and name:
#     #
#     # ```ruby
#     # drop_trigger "users", "do_something"
#     # ```
#     #
#     # the default name can be restored from its attributes as well.
#     #
#     # ```ruby
#     # drop_trigger "users" do |t|
#     #   t.function "send_notifications()"
#     #   t.for_each :row
#     #   t.type :after
#     #   t.events %i[update]
#     #   t.columns %w[email phone]
#     #   t.comment "Does something"
#     # end
#     # ```
#     #
#     # Notice, that you have to specify all attributes to make
#     # the operation reversible.
#     #
#     # The operation can be called with `if_exists` option. In this case
#     # it would do nothing when no trigger existed.
#     #
#     # ```ruby
#     # drop_trigger "users", "unknown_trigger", if_exists: true
#     # ```
#     #
#     # This option, though, makes the operation irreversible because of
#     # uncertainty of the previous state of the database.
#     def drop_trigger(table, name = nil, **options, &block); end
#   end
module PGTrunk::Operations::Triggers
  # @private
  class DropTrigger < Base
    validates :replace_existing, :new_name, absence: true

    def to_sql(_version)
      sql = "DROP TRIGGER"
      sql << " IF EXISTS" if if_exists
      sql << " #{name.name.inspect} ON #{table.to_sql};"
    end

    def invert
      irreversible!("if_exists: true") if if_exists
      CreateTrigger.new(**to_h)
    end
  end
end
