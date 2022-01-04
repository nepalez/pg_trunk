# frozen_string_literal: false

module PGExtra::Operations::Domains
  # @private
  # Definition for the domain's constraint
  class Constraint
    include ActiveModel::Model
    include ActiveModel::Attributes
    include ActiveModel::Validations

    def self.build(data)
      data.is_a?(self) ? data : new(**data)
    end

    attribute :check, :pg_extra_multiline_text
    attribute :drop, :boolean
    attribute :force, :pg_extra_symbol
    attribute :if_exists, :boolean
    attribute :name, :string
    attribute :new_name, :string
    attribute :valid, :boolean

    validates :name, presence: true
    validates :new_name, "PGExtra/difference": { from: :name }, allow_nil: true
    validates :force, inclusion: { in: %i[force restrict] }, allow_nil: true

    def to_h
      @to_h ||= attributes.compact.symbolize_keys
    end

    def opts
      to_h.slice(:name)
    end

    def invert
      @invert ||= {}.tap do |i|
        i[:name] = new_name.presence || name
        i[:new_name] = name if new_name.present?
        i[:drop] = !drop if new_name.blank?
        i[:check] = check if drop
      end
    end

    def to_sql
      rename_sql || drop_sql || add_sql || validate_sql
    end

    def inversion_error
      return <<~MSG.squish if if_exists
        with `if_exists: true` option cannot be inverted
        due to uncertainty of the previous state of the database.
      MSG

      return <<~MSG.squish if force == :cascade
        with `force: :cascade` option cannot be inverted
        due to uncertainty of the previous state of the database.
      MSG

      return if check.present?

      "the constraint `#{name}` is dropped without `check` option."
    end

    private

    def rename_sql
      <<~SQL.squish if new_name.present?
        RENAME CONSTRAINT #{name.inspect} TO #{new_name.inspect}
      SQL
    end

    def drop_sql
      return unless drop

      sql = "DROP CONSTRAINT"
      sql << " IF EXISTS" if if_exists
      sql << " #{name.inspect}"
      sql << " CASCADE" if force == :cascade
      sql << ";"
    end

    def add_sql
      <<~SQL.squish if check.present?
        ADD CONSTRAINT #{name.inspect}
        CHECK (#{check})#{' NOT VALID' unless valid}
      SQL
    end

    def validate_sql
      "VALIDATE CONSTRAINT #{name.inspect}" if valid
    end
  end
end
