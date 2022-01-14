# frozen_string_literal: true

# @private
module PGTrunk::Serializers
  # @private
  # Cast the attribute value as a qualified name.
  class QualifiedNameSerializer < ActiveRecord::Type::Value
    TYPE = ::PGTrunk::QualifiedName

    def cast(value)
      case value
      when NilClass then nil
      when TYPE then value
      else TYPE.wrap(value.to_s)
      end
    end

    def serialize(value)
      value.is_a?(TYPE) ? value.lean : value&.to_s
    end
  end

  ActiveModel::Type.register(
    :pg_trunk_qualified_name,
    PGTrunk::Serializers::QualifiedNameSerializer,
  )
end
