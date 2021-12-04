# frozen_string_literal: true

class PGExtra::Operation
  # Define getters/setters for the operation attributes
  module Attributes
    extend ActiveSupport::Concern
    include ActiveModel::Model
    include ActiveModel::Attributes

    # The special undefined value for getters/setters
    # to distinct it from the explicitly provided `nil`.
    UNDEFINED = Object.new.freeze
    private_constant :UNDEFINED

    class_methods do
      # list of aliases for attributes
      def attr_aliases
        @attr_aliases ||= {}
      end

      # Add an attribute to the operation
      def attribute(name, type, default: nil, aliases: nil)
        # prevent mutation of the default arrays, hashes etc.
        default = default.freeze if default.respond_to?(:freeze)
        super(name, type, default: default, &nil)
        # add the private attribute for the previous value
        attr_reader :"from_#{name}"

        redefine_getter(name)
        Array(aliases).each { |key| attr_aliases[key.to_sym] = name.to_sym }
        name.to_sym
      end

      private

      def redefine_getter(name)
        getter = instance_method(name)
        define_method(name) do |value = UNDEFINED, *args, from: nil|
          # fallback to the original getter w/o arguments
          return getter.bind(self).call if value == UNDEFINED

          # set a previous value to return to
          instance_variable_set("@from_#{name}", from)

          # arrays can be assigned as lists
          value = [value, *args] if args.any?

          send(:"#{name}=", value)
        end
      end

      def inherited(klass)
        klass.instance_variable_set(:@attr_aliases, attr_aliases)
        super
      end
    end

    def initialize(**opts)
      # enable aliases during the initialization
      self.class.attr_aliases.each do |a, n|
        opts[n] = opts.delete(a) if opts.key?(a)
      end
      # ignore unknown attributes (to simplify calls of `#invert`)
      opts = opts.slice(*self.class.attribute_names.map(&:to_sym))

      super(**opts)
    end

    # The hash of the operation's serialized attributes
    def attributes
      super.to_h do |k, v|
        [k.to_sym, self.class.attribute_types[k].serialize(v)]
      end
    end
    alias to_h attributes
  end
end
