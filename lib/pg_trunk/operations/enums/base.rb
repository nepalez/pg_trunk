# frozen_string_literal: false

module PGTrunk::Operations::Enums
  # @abstract
  # @private
  # Base class for operations with enumerated types
  class Base < PGTrunk::Operation
    # All attributes that can be used by enum-related commands
    attribute :changes, :pg_trunk_array_of_hashes, default: []
    attribute :values, :pg_trunk_array_of_strings, default: []

    # populate values one-by-one in a block
    def value(value)
      values << value.to_s
    end

    # wrap change definitions into value objects
    after_initialize { changes.map! { |change| Change.build(change) } }

    validates :if_not_exists, absence: true
    validates :name, presence: true
    validates :changes, "PGTrunk/all_items_valid": true, allow_nil: true

    # Use comparison by name from pg_trunk operations base class (default)
    # Support name as the only positional argument (default)

    ruby_snippet do |s|
      s.ruby_param(name.lean) if name.present?
      s.ruby_param(to: new_name) if new_name.present?
      s.ruby_param(if_exists: true) if if_exists
      s.ruby_param(force: :cascade) if force == :cascade

      if values.join(", ").length < 60
        s.ruby_line(:values, *values)
      else
        values.each { |value| s.ruby_line(:value, value) }
      end
      changes.select(&:add?).each do |change|
        s.ruby_line(:add_value, change.name, **change.opts)
      end
      changes.select(&:rename?).each do |change|
        s.ruby_line(:rename_value, change.name, to: change.new_name)
      end
      s.ruby_line(:comment, comment) if comment.present?
    end
  end
end
