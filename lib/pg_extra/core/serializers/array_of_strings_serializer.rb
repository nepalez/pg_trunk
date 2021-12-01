# frozen_string_literal: true

# nodoc
module PGExtra::Serializers
  # @api private
  # Cast the attribute value as an array of strings.
  # It knows how to cast arrays returned by PostgreSQL
  # as a string like '{USD,EUR,GBP}' into ['USD', 'EUR', 'GBP'].
  class ArrayOfStringsSerializer < ActiveRecord::Type::Value
    def cast(value)
      case value
      when ::String
        value.gsub(/^\{|\}$/, "").split(",")
      when ::NilClass then []
      when ::Array then value.map(&:to_s)
      else [value.to_s]
      end
    end

    def serialize(value)
      value
    end
  end

  ActiveModel::Type.register(
    :pg_extra_array_of_strings,
    ArrayOfStringsSerializer,
  )
end
