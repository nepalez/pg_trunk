# frozen_string_literal: true

module PGExtra
  # @private
  # Namespace for the gem-specific activemodel serializers
  module Serializers
    require_relative "serializers/array_serializer"
    require_relative "serializers/array_of_hashes_serializer"
    require_relative "serializers/array_of_strings_serializer"
    require_relative "serializers/array_of_symbols_serializer"
    require_relative "serializers/lowercase_string_serializer"
    require_relative "serializers/multiline_text_serializer"
    require_relative "serializers/qualified_name_serializer"
    require_relative "serializers/symbol_serializer"
  end
end
