# frozen_string_literal: true

# nodoc
module PGTrunk::Operations
  # Namespace for operations with aggregates
  module Aggregators
    require_relative "aggregates/state_function"
    require_relative "aggregates/base"
    require_relative "aggregates/create_aggregate"
    require_relative "aggregates/drop_aggregate"
    require_relative "aggregates/rename_aggregate"
  end
end
