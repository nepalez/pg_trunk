# frozen_string_literal: true

module PGExtra
  # Namespace for the gem-specific activemodel validators
  module Validators
    require_relative "validators/all_items_valid_validator"
    require_relative "validators/difference_validator"
  end
end
