# frozen_string_literal: true

# nodoc
module PGTrunk::Operations
  # @private
  # Namespace for operations with triggers
  module Triggers
    require_relative "triggers/base"
    require_relative "triggers/change_trigger"
    require_relative "triggers/create_trigger"
    require_relative "triggers/drop_trigger"
    require_relative "triggers/rename_trigger"
  end
end
