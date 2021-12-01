# frozen_string_literal: true

module PGExtra
  # @api private
  # Namespace for creator definitions and their fetchers
  module Operations
    # The order of requirements is essential:
    # in this order independent objects will be dumped to the schema.
    require_relative "operations/tables"
  end
end
