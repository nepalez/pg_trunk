# frozen_string_literal: false

module PGExtra::Operations::Enums
  # @private
  # Definition for the value's change
  class Change
    include ActiveModel::Model
    include ActiveModel::Attributes
    include ActiveModel::Validations

    def self.build(data)
      data.is_a?(self) ? data : new(**data)
    end

    attribute :name, :string
    attribute :new_name, :string
    attribute :after, :string
    attribute :before, :string

    validates :name, presence: true
    validates :new_name, "PGExtra/difference": { from: :name }, allow_nil: true
    validate { errors.add :after,  :present if rename? && after.present? }
    validate { errors.add :before, :present if rename? && before.present? }
    validate { errors.add :before, :present if [after, before].all?(&:present?) }

    def rename?
      new_name.present?
    end

    def add?
      new_name.blank?
    end

    def to_h
      attributes.compact.symbolize_keys
    end

    def opts
      to_h.slice(:before, :after).compact
    end

    def invert
      { name: new_name, new_name: name }
    end

    def to_sql
      return "RENAME VALUE '#{name}' TO '#{new_name}'" if new_name.present?

      sql = "ADD VALUE IF NOT EXISTS $value$#{name}$value$"
      sql << " BEFORE $value$#{before}$value$" if before.present?
      sql << " AFTER $value$#{after}$value$" if after.present?
      sql
    end
  end
end
