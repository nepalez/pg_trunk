# frozen_string_literal: true

# nodoc
module PGExtra::Operations
  # @private
  # Namespace for operations with functions
  module Functions
    require_relative "functions/base"
    require_relative "functions/create_function"
    require_relative "functions/change_function"
    require_relative "functions/drop_function"
    require_relative "functions/rename_function"
  end
end
