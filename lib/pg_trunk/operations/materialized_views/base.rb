# frozen_string_literal: false

module PGTrunk::Operations::MaterializedViews
  # @abstract
  # @private
  # Base class for operations with views
  class Base < PGTrunk::Operation
    # All attributes that can be used by view-related commands
    attribute :algorithm, :pg_trunk_symbol
    attribute :cluster_on, :string
    attribute :columns, :pg_trunk_array_of_hashes, default: []
    attribute :sql_definition, :pg_trunk_multiline_text
    attribute :tablespace, :string
    attribute :version, :integer, aliases: :revert_to_version
    attribute :with_data, :boolean

    def column(name, **opts)
      columns << Column.new(name: name, **opts.except(:new_name))
    end

    # Load missed `sql_definition` from the external file
    after_initialize { self.sql_definition ||= read_snippet_from(:materialized_views) }
    after_initialize { columns.map! { |c| Column.build(c) } }

    # Ensure correctness of present values
    validates :algorithm, inclusion: %i[concurrently], allow_nil: true
    validates :tablespace, exclusion: { in: [UNDEFINED] }, allow_nil: true
    validates :columns, "PGTrunk/all_items_valid": true, allow_nil: true

    # Use comparison by name from pg_trunk operations base class (default)
    # Support name as the only positional argument (default)

    ruby_snippet do |s|
      s.ruby_param(name.lean) if name.present?
      s.ruby_param(version: version) if version.present?
      s.ruby_param(to: new_name.lean) if new_name.present?
      s.ruby_param(if_exists: true) if if_exists
      s.ruby_param(if_not_exists: true) if if_not_exists
      s.ruby_param(force: :cascade) if force == :cascade

      s.ruby_line(:sql_definition, sql_definition) if version.blank?
      s.ruby_line(:tablespace, tablespace) if tablespace.present?
      s.ruby_line(:cluster_on, cluster_on) if cluster_on.present?
      columns.reject(&:new_name).each do |c|
        s.ruby_line(:column, c.name, **c.changes)
      end
      columns.select(&:new_name).each do |c|
        s.ruby_line(:rename_column, c.name, to: c.new_name)
      end
      s.ruby_line(:with_data, false) if with_data == false
      s.ruby_line(:comment, comment, from: from_comment) if comment
    end

    private

    # A special constant to distinct cluster resetting from nil
    RESET = Object.new.freeze

    def validate_naming!(name: nil, **)
      errors.add :columns, "has undefined names" if name.blank?
    end

    def validate_definition!(name: nil, **opts)
      return if opts.none? { |_, value| value == UNDEFINED }

      errors.add :base, "Definition of column #{name} can't be reverted"
    end

    def validate_statistics!(name: nil, **opts)
      opts.values_at(*STATISTICS).each do |value|
        next if value.nil? || value == UNDEFINED
        next if value.is_a?(Numeric) && value >= 0

        errors.add :base, "Column #{name} has invalid statistics #{value}"
        break
      end
    end
  end
end
