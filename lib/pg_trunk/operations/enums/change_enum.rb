# frozen_string_literal: false

# @!parse
#   class ActiveRecord::Migration
#     # Modify an enumerated type
#     #
#     # @param [#to_s] name (nil) The qualified name of the type
#     # @yield [e] the block with the type's definition
#     # @yieldparam Object receiver of methods specifying the type
#     # @return [void]
#     #
#     # The operation can be used to rename or add values to the
#     # enumerated type. The commend can be changed as well.
#     #
#     #   change_enum "currencies" do |e|
#     #     e.add_value "EUR", after: "BTC"
#     #     e.add_value "GBP", before: "usd"
#     #     e.add_value "JPY" # to the end of the list
#     #     e.rename_value "usd", to: "USD"
#     #     e.comment <<~COMMENT, from: <<~COMMENT
#     #       Supported currencies
#     #     COMMENT
#     #       Currencies
#     #     COMMENT
#     #   end
#     #
#     # Please, keep in mind that all values will be added before
#     # the first rename. That's why you should use old values
#     # (like the `usd` instead of the `USD` in the example above)
#     # in `before` and `after` options.
#     #
#     # Also notice that PostgreSQL doesn't support value deletion,
#     # that's why adding any value makes the migration irreversible.
#     #
#     # It is also irreversible if you changed the comment, but
#     # not defined its previous value.
#     def change_enum(name, &block); end
#   end
module PGTrunk::Operations::Enums
  # @private
  class ChangeEnum < Base
    # Add new value (irreversible!)
    # If neither option is specified, the value will be added
    # to the very end of the array.
    # Notice, that all add-ons are made BEFORE renames.
    def add_value(name, after: nil, before: nil)
      changes << Change.new(name: name, after: after, before: before)
    end

    # Rename the value to new unique name (reversible)
    def rename_value(name, to: nil)
      changes << Change.new(name: name, new_name: to)
    end

    validates :if_exists, :force, :values, :new_name, absence: true
    validate do
      next if comment.present? || changes.present?

      errors.add :base, "There are no changes"
    end

    def to_sql(version)
      raise <<~MSG.squish if version < "12" && changes.any?(&:add?)
        Adding new values to enumerable types inside a migration
        is supported in PostgreSQL v12+.
      MSG

      [*add_values, *rename_values, *change_comment].join(" ")
    end

    def invert
      values_added = changes.any?(&:add?)
      raise IrreversibleMigration.new(self, nil, <<~MSG.squish) if values_added
        Removal of values from enumerated type is not supported by PostgreSQL,
        that's why adding new values can't be reverted.
      MSG

      undefined = inversion.select { |_, v| v.nil? }.keys.join(", ").presence
      raise IrreversibleMigration.new(self, nil, <<~MSG.squish) if undefined
        Undefined values to revert #{undefined}.
      MSG

      self.class.new(**to_h, **inversion)
    end

    def to_h
      super.tap { |data| data[:changes]&.map!(&:to_h) }
    end

    private

    def add_values
      changes.select(&:add?).map do |change|
        "ALTER TYPE #{name.to_sql} #{change.to_sql};"
      end
    end

    def rename_values
      changes.select(&:rename?).map do |change|
        "ALTER TYPE #{name.to_sql} #{change.to_sql};"
      end
    end

    def change_comment
      return unless comment # empty string is processed

      "COMMENT ON TYPE #{name.to_sql} IS $comment$#{comment}$comment$;"
    end

    def change
      @change ||= {
        changes: changes.map(&:to_h).presence, comment: comment,
      }.compact
    end

    def inversion
      @inversion ||= {
        changes: changes.reverse.map(&:invert).presence, comment: from_comment,
      }.slice(*change.keys)
    end
  end
end
