# frozen_string_literal: true

# nodoc
module PGTrunk::Operations
  # @private
  # Namespace for operations with rules
  module Rules
    require_relative "rules/base"
    require_relative "rules/create_rule"
    require_relative "rules/drop_rule"
    require_relative "rules/rename_rule"
  end
end
