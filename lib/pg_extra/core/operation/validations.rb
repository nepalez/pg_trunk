# frozen_string_literal: true

class PGExtra::Operation
  # @private
  # Enable validation of the operation in the Rails way
  module Validations
    extend ActiveSupport::Concern

    class_methods do
      extend ActiveModel::Validations
    end

    def error_messages
      errors.messages.flat_map do |k, v|
        Array(v).map do |msg|
          k == :base ? msg : [k, msg].join(" ")
        end
      end
    end
  end
end
