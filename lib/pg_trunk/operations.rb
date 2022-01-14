# frozen_string_literal: true

# @private
module PGTrunk
  # Namespace for creator definitions and their fetchers
  module Operations
    # The order of requirements is essential:
    # in this order independent objects will be dumped to the schema.
    require_relative "operations/enums"
    require_relative "operations/composite_types"
    require_relative "operations/domains"
    require_relative "operations/sequences"
    require_relative "operations/tables"
    require_relative "operations/views"
    require_relative "operations/materialized_views"
    require_relative "operations/functions"
    require_relative "operations/indexes"
    require_relative "operations/aggregates"
    require_relative "operations/check_constraints"
    require_relative "operations/foreign_keys"
    require_relative "operations/procedures"
    require_relative "operations/triggers"
    require_relative "operations/rules"
    require_relative "operations/statistics"
  end
end
