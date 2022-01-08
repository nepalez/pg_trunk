# frozen_string_literal: true

# nodoc
module PGExtra::Operations
  # @private
  # Namespace for operations with functions
  module Domains
    require_relative "domains/constraint"
    require_relative "domains/base"
    require_relative "domains/change_domain"
    require_relative "domains/create_domain"
    require_relative "domains/drop_domain"
    require_relative "domains/rename_domain"
  end
end
