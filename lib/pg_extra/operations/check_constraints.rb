# frozen_string_literal: true

# nodoc
module PGExtra::Operations
  # Definitions for check constraints
  module CheckConstraints
    require_relative "check_constraints/base"
    require_relative "check_constraints/add_check_constraint"
    require_relative "check_constraints/drop_check_constraint"
    require_relative "check_constraints/rename_check_constraint"
    require_relative "check_constraints/validate_check_constraint"
  end
end
