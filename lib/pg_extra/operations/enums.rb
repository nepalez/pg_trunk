# frozen_string_literal: true

# nodoc
module PGExtra::Definitions
  # Namespace for operations with functions
  module Enums
    require_relative "enums/change"
    require_relative "enums/base"
    require_relative "enums/change_enum"
    require_relative "enums/create_enum"
    require_relative "enums/drop_enum"
    require_relative "enums/rename_enum"
  end
end
