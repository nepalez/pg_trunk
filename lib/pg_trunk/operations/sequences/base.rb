# frozen_string_literal: false

module PGTrunk::Operations::Sequences
  # @abstract
  # @private
  # Base class for operations with sequences
  class Base < PGTrunk::Operation
    attribute :type, :string, aliases: :as
    attribute :increment_by, :integer
    attribute :min_value, :integer
    attribute :max_value, :integer
    attribute :start_with, :integer
    attribute :cache, :integer
    attribute :cycle, :boolean
    attribute :table, :string
    attribute :column, :string

    def owned_by(table, column)
      self.table = table
      self.column = column
    end

    # Ensure correctness of present values
    # The table must be defined because the name only
    # is not enough to identify the constraint.
    validates :name, presence: true
    validates :cache, numericality: { greater_than_or_equal_to: 1 }, allow_nil: true
    validate { errors.add :base, "Increment must not be zero" if increment_by&.zero? }
    validate do
      next unless table.present? ^ column.present?

      errors.add :base, "Both table and column must be set"
    end
    validate do
      next if min_value.blank? || max_value.blank? || min_value <= max_value

      errors.add :base, "Min value must not exceed max value"
    end
    validate do
      next if start_with.blank? || min_value.blank? || start_with >= min_value

      errors.add :base, "start value cannot be less than min value"
    end
    validate do
      next if start_with.blank? || max_value.blank? || start_with <= max_value

      errors.add :base, "start value cannot be greater than max value"
    end

    # Use comparison by name from pg_trunk operations base class (default)
    # Support name as the only positional argument (default)

    # Snippet to be used in all operations with rules
    ruby_snippet do |s|
      s.ruby_param(name.lean) if name.present?
      s.ruby_param(as: type) if type.present? && from_type.blank?
      s.ruby_param(to: new_name) if new_name.present?
      s.ruby_param(if_exists: true) if if_exists
      s.ruby_param(if_not_exists: true) if if_not_exists
      s.ruby_param(force: :cascade) if force == :cascade

      s.ruby_line(:type, type, from: from_type) if from_type.present?
      s.ruby_line(:owned_by, table, column) if table.present? || column.present?
      s.ruby_line(:increment_by, increment_by, from: from_increment_by) if increment_by&.!= 1
      s.ruby_line(:min_value, min_value, from: from_min_value) if min_value.present?
      s.ruby_line(:max_value, max_value, from: from_max_value) if max_value.present?
      s.ruby_line(:start_with, start_with, from: from_start_with) if custom_start?
      s.ruby_line(:cache, cache, from: from_cache) if cache&.!= 1
      s.ruby_line(:cycle, cycle) unless cycle.nil?
      s.ruby_line(:comment, comment, from: from_comment) if comment.present?
    end

    private

    def custom_start?
      increment_by&.<(0) ? start_with&.!=(max_value) : start_with&.!=(min_value)
    end
  end
end
