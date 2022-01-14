# frozen_string_literal: true

# @private
module PGTrunk::Serializers
  # @private
  # Cast the attribute value as an array of strings.
  # It knows how to cast arrays returned by PostgreSQL
  # as a string like '{USD,EUR,GBP}' into ['USD', 'EUR', 'GBP'].
  class ArrayOfHashesSerializer < ActiveRecord::Type::Value
    def cast(value)
      case value
      when ::String then JSON.parse(value).map(&:symbolize_keys)
      when ::NilClass then []
      when ::Array then value.map(&:to_h)
      else [value.to_h]
      end
    end

    def serialize(value)
      Array.wrap(value).map { |item| item.to_h.symbolize_keys }
    end
  end

  ActiveModel::Type.register(
    :pg_trunk_array_of_hashes,
    ArrayOfHashesSerializer,
  )
end
