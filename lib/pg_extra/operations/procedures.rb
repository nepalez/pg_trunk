# frozen_string_literal: true

# nodoc
module PGExtra::Definitions
  # Namespace for operations with procedures
  module Procedures
    require_relative "procedures/base"
    require_relative "procedures/change_procedure"
    require_relative "procedures/create_procedure"
    require_relative "procedures/drop_procedure"
    require_relative "procedures/rename_procedure"
  end
end
