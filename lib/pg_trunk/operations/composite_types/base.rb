# frozen_string_literal: false

module PGTrunk::Operations::CompositeTypes
  # @abstract
  # @private
  # Base class for operations with composite types
  class Base < PGTrunk::Operation
    # All columns that can be used by type-related commands
    attribute :columns, :pg_trunk_array_of_hashes, default: []

    # Populate columns from a block
    def column(name, type, collation: nil)
      columns << Column.new(name: name, type: type, collation: collation)
    end

    # Wrap column definitions to value objects
    after_initialize { columns.map! { |a| Column.build(a) } }

    validates :if_not_exists, absence: true
    validates :name, presence: true
    validates :columns, "PGTrunk/all_items_valid": true, allow_nil: true

    # Use comparison by name from pg_trunk operations base class (default)
    # Support name as the only positional argument (default)

    ruby_snippet do |s|
      s.ruby_param(name.lean) if name.present?
      s.ruby_param(to: new_name.lean) if new_name.present?
      s.ruby_param(if_exists: true) if if_exists
      s.ruby_param(force: :cascade) if force == :cascade

      columns.reject(&:change).each do |c|
        s.ruby_line(
          :column, c.name, c.type&.lean, collation: c.collation&.lean,
        )
      end
      columns.select { |c| c.change == :add }.each do |c|
        s.ruby_line(
          :add_column, c.name, c.type&.lean, collation: c.collation&.lean,
        )
      end
      columns.select { |c| c.change == :rename }.each do |c|
        s.ruby_line(:rename_column, c.name, to: c.new_name)
      end
      columns.select { |c| c.change == :alter }.each do |c|
        s.ruby_line(
          :change_column, c.name, c.type&.lean,
          collation: c.collation&.lean,
          from_type: c.from_type&.lean,
          from_collation: c.from_collation&.lean,
        )
      end
      columns.select { |c| c.change == :drop }.each do |c|
        s.ruby_line(
          :drop_column, c.name, *c.type&.lean, collation: c.collation&.lean,
        )
      end
      s.ruby_line(:comment, comment, from: from_comment) if comment
    end
  end
end
