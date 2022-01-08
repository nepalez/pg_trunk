# frozen_string_literal: true

# @private
module PGExtra::Serializers
  # @private
  # The same as the array of strings with symbolization at the end
  class ArrayOfSymbolsSerializer < ActiveRecord::Type::Value
    def cast(value)
      case value
      when ::NilClass then []
      when ::Symbol then [value]
      when ::String
        value.gsub(/^\{|\}$/, "").split(",").map(&:to_sym)
      when ::Array then value.map { |i| i.to_s.to_sym }
      else [value.to_s.to_sym]
      end
    end

    def serialize(value)
      value
    end
  end

  ActiveModel::Type.register(
    :pg_extra_array_of_symbols,
    ArrayOfSymbolsSerializer,
  )
end
