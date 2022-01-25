# frozen_string_literal: true

# nodoc
module PGTrunk::Operations
  # @private
  # Namespace for operations with sequences
  module Sequences
    require_relative "sequences/base"
    require_relative "sequences/change_sequence"
    require_relative "sequences/create_sequence"
    require_relative "sequences/drop_sequence"
    require_relative "sequences/rename_sequence"
  end
end
