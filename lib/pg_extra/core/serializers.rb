# frozen_string_literal: true

module PGExtra
  # Namespace for the gem-specific activemodel serializers
  module Serializers
    require_relative "serializers/array_serializer"
    require_relative "serializers/array_of_strings_serializer"
    require_relative "serializers/qualified_name_serializer"
    require_relative "serializers/symbol_serializer"
  end
end
