# frozen_string_literal: true

# @private
module PGTrunk::Serializers
  # @private
  # Cast the attribute value as a non-empty stripped string in lowercase
  class LowercaseStringSerializer < ActiveRecord::Type::Value
    def cast(value)
      value.to_s.presence&.downcase&.strip
    end

    def serialize(value)
      value.to_s
    end
  end

  ActiveModel::Type.register(
    :pg_trunk_lowercase_string,
    LowercaseStringSerializer,
  )
end
