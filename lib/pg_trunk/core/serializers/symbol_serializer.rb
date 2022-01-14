# frozen_string_literal: true

# @private
module PGTrunk::Serializers
  # @private
  # Cast the attribute value as a symbol.
  class SymbolSerializer < ActiveRecord::Type::Value
    def cast(value)
      return if value.blank?
      return value if value.is_a?(Symbol)
      return value.to_sym if value.respond_to?(:to_sym)

      value.to_s.to_sym
    end

    def serialize(value)
      value
    end
  end

  ActiveModel::Type.register(:pg_trunk_symbol, SymbolSerializer)
end
