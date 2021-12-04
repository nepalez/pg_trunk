# frozen_string_literal: true

# nodoc
module PGExtra::Serializers
  # @api private
  # Cast the attribute value as a qualified name.
  class QualifiedNameSerializer < ActiveRecord::Type::Value
    TYPE = ::PGExtra::QualifiedName

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
    :pg_extra_qualified_name,
    PGExtra::Serializers::QualifiedNameSerializer,
  )
end
