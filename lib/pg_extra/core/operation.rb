# frozen_string_literal: false

require_relative "operation/callbacks"

module PGExtra
  # @api private
  # Base class for operations.
  # Inherit this class to define new operation.
  class Operation
    include Callbacks
  end
end
