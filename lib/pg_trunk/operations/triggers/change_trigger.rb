# frozen_string_literal: false

# @!parse
#   class ActiveRecord::Migration
#     # Create a trigger for a table
#     #
#     # @param [#to_s] table (nil) The qualified name of the table
#     # @param [#to_s] name (nil) The name of the trigger
#     # @option [Boolean] :if_exists (false) Suppress the error when the trigger is absent
#     # @yield [t] the block with the trigger's definition
#     # @yieldparam Object receiver of methods specifying the trigger
#     # @return [void]
#     #
#     # The trigger can be changed using `CREATE OR REPLACE TRIGGER` command:
#     #
#     #   change_trigger "users", "do_something" do |t|
#     #     t.function "do_something()", from: "do_something_different()"
#     #     t.for_each :row # from: :statement
#     #     t.type :after, from: :before
#     #     t.events %i[insert update], from: %i[insert]
#     #     t.comment "Does something useful", from: ""
#     #   end
#     def create_trigger(table, name = nil, **options, &block); end
#   end
module PGTrunk::Operations::Triggers
  # @private
  class ChangeTrigger < Base
    validates :replace_existing, :new_name, :version, absence: true
    validate { errors.add :base, "Changes can't be blank" if changes.blank? }
    validate do
      next if if_exists

      errors.add :base, "The trigger cannot be found" unless create_trigger
    end

    def to_sql(server_version)
      return create_trigger&.to_sql(server_version) if server_version >= "14"

      raise "The operation is supported by PostgreSQL server v14+"
    end

    def invert
      irreversible!("if_exists: true") if if_exists
      undefined = inversion.select { |_, v| v.nil? }.keys.join(", ").presence
      raise IrreversibleMigration.new(self, nil, <<~MSG.squish) if undefined
        Undefined values to revert #{undefined}.
      MSG

      self.class.new(**inversion, table: table, name: name)
    end

    private

    def changes
      @changes ||= {
        type: type.presence,
        events: events.presence,
        columns: columns.presence,
        constraint: constraint,
        for_each: for_each,
        function: function.presence,
        initially: initially,
        when: self.when.presence,
        comment: comment,
      }.compact
    end

    def inversion
      changes
        .each_with_object({}) { |(k, _), obj| obj[k] = send(:"from_#{k}") }
        .tap do |i|
          i[:for_each] ||= (%i[statement row] - [for_each]).first if for_each
        end
    end

    def create_trigger
      return if name.blank? || table.blank?

      @create_trigger ||=
        CreateTrigger
        .find { |o| o.name == name && o.table == table }
        &.tap { |o| o.attributes = { **changes, replace_existing: true } }
    end
  end
end
