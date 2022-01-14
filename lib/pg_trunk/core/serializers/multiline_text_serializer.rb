# frozen_string_literal: true

# @private
module PGTrunk::Serializers
  # @private
  # Cast the attribute value as a multiline text
  # with right-stripped lines and without empty lines.
  class MultilineTextSerializer < ActiveRecord::Type::Value
    def cast(value)
      return if value.blank?

      value.to_s.lines.map(&:strip).reject(&:blank?).join("\n")
    end

    def serialize(value)
      value&.to_s
    end
  end

  ActiveModel::Type.register(:pg_trunk_multiline_text, MultilineTextSerializer)
end
