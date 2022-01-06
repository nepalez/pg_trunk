# frozen_string_literal: false

module PGExtra::Operations::CompositeTypes
  # @private
  # Definition for an column of a composite type
  class Column
    include ActiveModel::Model
    include ActiveModel::Attributes
    include ActiveModel::Validations

    def self.build(data)
      data.is_a?(self) ? data : new(**data)
    end

    attribute :change, :pg_extra_symbol
    attribute :collation, :pg_extra_qualified_name
    attribute :force, :pg_extra_symbol
    attribute :from_collation, :pg_extra_qualified_name
    attribute :from_type, :pg_extra_qualified_name
    attribute :if_exists, :boolean
    attribute :name, :string
    attribute :new_name, :string
    attribute :type, :pg_extra_qualified_name

    validates :name, presence: true
    validates :new_name, "PGExtra/difference": { from: :name }, allow_nil: true
    validates :change, inclusion: { in: %i[add alter drop rename] }, allow_nil: true
    validates :force, inclusion: { in: %i[force restrict] }, allow_nil: true

    def to_h
      @to_h ||= attributes.compact.symbolize_keys
    end

    INVERTED = {
      add: :drop, drop: :add, rename: :rename, alter: :alter,
    }.freeze

    def invert
      @invert ||= {}.tap do |i|
        i[:change] = INVERTED[change]
        i[:name] = new_name.presence || name
        i[:new_name] = name if new_name.present?
        i[:type] = change == :add ? type : from_type
        i[:collation] = change == :add ? collation : from_collation
      end
    end

    def to_sql
      case change
      when :add    then add_sql
      when :alter  then alter_sql
      when :drop   then drop_sql
      when :rename then rename_sql
      else sql
      end
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

      return <<~MSG.squish if change == :drop && type.blank?
        undefined type of the dropped column #{name}
      MSG

      return <<~MSG.squish if change == :alter && type && !from_type
        undefined a previous state of the type for column #{name}
      MSG

      return <<~MSG.squish if change == :alter && collation && !from_collation
        undefined a previous state of the collation for column #{name}
      MSG
    end

    private

    def rename_sql
      "RENAME ATTRIBUTE #{name.inspect} TO #{new_name.inspect}".tap do |sql|
        sql << " CASCADE" if force == :cascade
      end
    end

    def drop_sql
      "DROP ATTRIBUTE".tap do |sql|
        sql << " IF EXISTS" if if_exists
        sql << " #{name.inspect}"
        sql << " CASCADE" if force == :cascade
      end
    end

    def add_sql
      "ADD ATTRIBUTE #{name.inspect} #{type.lean}".tap do |sql|
        sql << " COLLATE #{collation.to_sql}" if collation.present?
        sql << " CASCADE" if force == :cascade
      end
    end

    def alter_sql
      "ALTER ATTRIBUTE #{name.inspect} SET DATA TYPE #{type.lean}".tap do |sql|
        sql << " COLLATE #{collation.to_sql}" if collation.present?
        sql << " CASCADE" if force == :cascade
      end
    end

    def sql
      "#{name.inspect} #{type.lean}".tap do |sql|
        sql << " COLLATE #{collation.to_sql}" if collation
      end
    end
  end
end
