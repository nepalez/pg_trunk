# frozen_string_literal: false

# @!method ActiveRecord::Migration#rename_trigger(table, name = nil, **options, &block)
# Rename a trigger
#
# @param [#to_s] table (nil) The qualified name of the table
# @param [#to_s] name (nil) The name of the trigger
# @option [#to_s] :to (nil) The new name of the trigger
# @param [#to_s] table (nil) The qualified name of the table
# @param [#to_s] name (nil) The current name of the trigger
# @option [#to_s] :to (nil) The new name for the trigger
# @option [#to_s] :function (nil) The qualified name of the function to be called
# @option [Symbol] :type (nil) When the trigger should be run
#   Supported values: :before, :after, :instead_of
# @option [Array<Symbol>] :events List of events running the trigger
#   Supported values in the array: :insert, :update, :delete, :truncate
# @option [Symbol] :for_each (:statement) Define if a trigger should be run for every row
#   Supported values: :statement (default), :row
# @yield [Proc] the block with the trigger's definition
# @yieldparam The receiver of methods specifying the trigger
#
# A trigger can be renamed by either setting a new name explicitly
#
#   rename_trigger "users", "do_something", to: "do_something_different"
#
# or resetting it to the default (generated) value.
#
#   rename_trigger "users", "do_something"
#
# The previously generated name of the trigger can be get
# from its parameters. In this case all the essentials
# parameters must be specified:
#
#   rename_trigger "users", to: "do_something_different" do |t|
#     t.function "do_something()"
#     t.for_each :row
#     t.type :after
#     t.events %i[insert update]
#   end
#
# In the same way, when you reset the name to default,
# all the essential parameters must be got to make the trigger
# invertible.
#
#   rename_trigger "users", "do_something" do |t|
#     t.function "do_something()"
#     t.for_each :row
#     t.type :after
#     t.events %i[insert update]
#   end

module PGExtra::Operations::Triggers
  # @private
  class RenameTrigger < Base
    after_initialize { self.new_name = generated_name if new_name.blank? }

    validates :if_exists, :constraint, :initially, :when, :replace_existing, absence: true
    validates :new_name, presence: true

    def to_sql(_version)
      <<~SQL.squish
        ALTER TRIGGER #{name.name.inspect} ON #{table.to_sql}
        RENAME TO #{new_name.name.inspect};
      SQL
    end

    def invert
      self.class.new(**to_h, name: new_name, to: name)
    end
  end
end
