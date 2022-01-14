# frozen_string_literal: true

# @private
module PGTrunk::Serializers
  # @private
  # Cast the attribute value as an array, not caring about its content.
  class ArraySerializer < ActiveRecord::Type::Value
    def cast(value)
      case value
      when ::NilClass then []
      when ::Array then value
      else [value]
      end
    end

    def serialize(value)
      value
    end
  end

  ActiveModel::Type.register(:pg_trunk_array, ArraySerializer)
end
