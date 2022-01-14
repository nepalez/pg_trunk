# frozen_string_literal: false

module PGTrunk::Operations::Aggregates
  # Keeps definition for the state function of the aggregate
  class StateFunction
    def self.attribute(name)
      define_method(name) do |value = nil|
        iname = :"@#{name}"
        return instance_variable_get(iname) if instance_variable_defined?(iname)

        instance_variable_set(iname, value) if value
      end
    end

    attr_reader :name

    attribute :type
    attribute :inverse
    attribute :space
    attribute :final
    attribute :extra
    attribute :modify
    attribute :initial

    private def initialize(name, **args, &block)
      @name = name
      args.each { |k, v| instance_variable_set(:"@#{k}", v) }
      block.call(self) if name.present? && block
    end
  end
end
