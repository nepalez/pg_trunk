# frozen_string_literal: true

# nodoc
module PGTrunk::Operations
  # @private
  # Namespace for operations with functions
  module Statistics
    require_relative "statistics/base"
    require_relative "statistics/create_statistics"
    require_relative "statistics/drop_statistics"
    require_relative "statistics/rename_statistics"
  end
end
