# frozen_string_literal: true

# nodoc
module PGExtra::Operations
  # Definitions for foreign keys
  #
  # We overload only add/drop operations to support features
  # like composite keys along with anonymous key deletion.
  module ForeignKeys
    require_relative "foreign_keys/base"
    require_relative "foreign_keys/add_foreign_key"
    require_relative "foreign_keys/drop_foreign_key"
    require_relative "foreign_keys/rename_foreign_key"
  end
end
