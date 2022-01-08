# frozen_string_literal: true

# nodoc
module PGExtra::Operations
  # @private
  # Definitions for composite types
  module CompositeTypes
    require_relative "composite_types/column"
    require_relative "composite_types/base"
    require_relative "composite_types/change_composite_type"
    require_relative "composite_types/create_composite_type"
    require_relative "composite_types/drop_composite_type"
    require_relative "composite_types/rename_composite_type"
  end
end
