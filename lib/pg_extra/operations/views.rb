# frozen_string_literal: true

# nodoc
module PGExtra::Operations
  # @private
  # Namespace for operations with views
  module Views
    require_relative "views/base"
    require_relative "views/change_view"
    require_relative "views/create_view"
    require_relative "views/drop_view"
    require_relative "views/rename_view"
  end
end
