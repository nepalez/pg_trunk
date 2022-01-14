# frozen_string_literal: true

# @private
# Ensure that an attribute is different from another one
class PGTrunk::DifferenceValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    another_name = options.fetch(:from)
    another_value = record.send(another_name).presence

    case another_value
    when PGTrunk::QualifiedName
      return unless value.maybe_eq?(another_value)
    else
      return unless value == another_value
    end

    record.errors.add attribute, "must be different from the #{another_name}"
  end
end
