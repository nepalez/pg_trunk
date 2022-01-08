# frozen_string_literal: true

class PGExtra::Operation
  # @private
  # Register attributes definition for later usage by generators
  module Generators
    extend ActiveSupport::Concern

    class_methods do
      # Gets or sets object name for the generator
      def generates_object(name = nil)
        @generates_object = name if name
        @generates_object ||= nil
      end

      # The definitions of the attributes
      # @return [Hash{Symbol => Hash{type:, default:, desc:}}]
      def attributes
        @attributes ||= {}
      end

      def attribute(name, type, default: nil, desc: nil, **opts)
        name = name.to_sym
        attributes[name] = {
          type: gen_type(type),
          default: default,
          desc: desc,
        }
        super(name, type.to_sym, default: default, **opts)
      end

      private

      def inherited(klass)
        klass.instance_variable_set(:@attributes, attributes.dup)
        super
      end

      # Convert the type to the acceptable by Rails::Generator
      def gen_type(type)
        case type.to_s
        when "bool", "boolean"  then :boolean
        when "integer", "float" then :numeric
        when /^pg_extra_array/  then :array
        when /^pg_extra_hash/   then :hash
        else :string
        end
      end
    end
  end
end
