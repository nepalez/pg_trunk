# frozen_string_literal: true

module PGTrunk::Operations::MaterializedViews
  # @private
  # Definition for the column change
  class Column
    include ActiveModel::Model
    include ActiveModel::Attributes
    include ActiveModel::Validations

    def self.build(data)
      data.is_a?(self) ? data : new(**data)
    end

    attribute :name, :string
    attribute :new_name, :string
    attribute :storage, :pg_trunk_symbol
    attribute :from_storage, :pg_trunk_symbol
    attribute :statistics, :integer
    attribute :n_distinct, :float

    # Hashify definitions

    def to_h
      @to_h ||=
        attributes
        .symbolize_keys
        .transform_values(&:presence)
        .compact
    end

    def opts
      to_h.except(:name)
    end

    def changes
      opts.except(:new_name)
    end

    def invert
      return { name: new_name, new_name: name } if new_name.present?

      {
        name: name,
        storage: (from_storage || :UNDEFINED if storage.present?),
        statistics: (0 if statistics.present?),
        n_distinct: (0 if n_distinct.present?),
      }.compact
    end

    # Ensure if the definition was built properly

    validates :name, presence: true
    validate { errors.add(:base, :blank) if opts.none? }
    validates :statistics,
              numericality: { greater_than_or_equal_to: 0 },
              allow_nil: true
    validates :n_distinct,
              numericality: { greater_than_or_equal_to: -1 },
              allow_nil: true
    validates :storage, :from_storage,
              inclusion: { in: %i[plain extended external main] },
              allow_nil: true
    validate do
      next unless n_distinct&.positive?
      next if n_distinct.to_i == n_distinct

      errors.add :n_distinct, "with positive value must be integer"
    end

    def error_messages
      validate
      errors&.messages&.flat_map do |k, v|
        v.map do |msg|
          "Column #{name.inspect}: #{k == :base ? msg : "#{k} #{msg}"}"
        end
      end
    end

    # Build SQL snippets for the column definition
    # @return [Array<String>]
    def to_sql(_version = "10")
      return ["RENAME COLUMN #{name.inspect} TO #{new_name.inspect}"] if new_name

      alter = "ALTER COLUMN #{name.inspect}"
      [
        *("#{alter} SET STATISTICS #{statistics}" if statistics),
        *("#{alter} SET (n_distinct = #{n_distinct})" if n_distinct),
        *("#{alter} RESET (n_distinct)" if n_distinct&.zero?),
        *("#{alter} SET STORAGE #{storage.to_s.upcase}" if storage.present?),
      ]
    end
  end
end
