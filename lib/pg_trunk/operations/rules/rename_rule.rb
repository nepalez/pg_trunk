# frozen_string_literal: false

# @!parse
#   class ActiveRecord::Migration
#     # Rename a rule
#     #
#     # @param [#to_s] table (nil) The qualified name of the table
#     # @param [#to_s] name (nil) The current name of the rule
#     # @option options [#to_s] :to (nil) The new name for the rule
#     # @yield [c] the block with the constraint's definition
#     # @yieldparam Object receiver of methods specifying the constraint
#     # @return [void]
#     #
#     # A constraint can be identified by the table and explicit name
#     #
#     # ```ruby
#     # rename_rule :users, "_forbid_insertion", to: "_skip_insertion"
#     # ```
#     #
#     # Alternatively the name can be got from the event and kind.
#     #
#     # ```ruby
#     # rename_rule :users, to: "_skip_insertion" do |r|
#     #   r.event :insert
#     #   r.kind :instead
#     # end
#     # ```
#     #
#     # The name can be reset to auto-generated when
#     # the `:to` option is missed or blank:
#     #
#     # ```ruby
#     # rename_rule :users, "_skip_insertion" do |r|
#     #   r.event :insert
#     #   r.kind :instead
#     # end
#     # ```
#     #
#     # The operation is always reversible.
#     def rename_rule(table, name = nil, **options, &block); end
#   end
module PGTrunk::Operations::Rules
  # @private
  class RenameRule < Base
    after_initialize { self.new_name = generated_name if new_name.blank? }

    validates :new_name, presence: true
    validates :where, :command, :replace_existing, :force, :if_exists,
              absence: true

    def to_sql(_version)
      <<~SQL
        ALTER RULE #{name.to_sql} ON #{table.to_sql}
        RENAME TO #{new_name.to_sql};
      SQL
    end

    def invert
      self.class.new(**to_h, name: new_name, to: name)
    end
  end
end
