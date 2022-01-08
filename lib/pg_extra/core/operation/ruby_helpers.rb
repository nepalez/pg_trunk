# frozen_string_literal: true

class PGExtra::Operation
  # @private
  # Helpers to build ruby snippet from the operation definition
  module RubyHelpers
    extend ActiveSupport::Concern

    class_methods do
      # The name of the builder
      # @return [Symbol]
      def ruby_name
        @ruby_name ||= name.split("::").last.underscore.to_sym
      end

      # The name of the inverted builder
      # @return [Symbol]
      def ruby_iname
        "invert_#{ruby_name}".to_sym
      end

      # Get/set positional params of the ruby method
      #
      # @example Provide a method `add_check_constraint(table = nil, **opts)`
      #   class AddCheckConstraint < PGExtra::Operation
      #     ruby_params :table
      #     # ...
      #   end
      #
      def ruby_params(*params)
        @ruby_params = params.compact.map(&:to_sym) if params.any?
        @ruby_params ||= []
      end

      # Gets or sets the block building a ruby snippet
      #
      # @yieldparam [PGExtra::Operation::RubyBuilder]
      #
      # @example
      #   ruby_snippet do |s|
      #     s.ruby_param(comment: comment) if comment.present?
      #     values.each { |v| s.ruby_line(:value, v) }
      #   end
      #
      #   # will build something like
      #
      #   do_something "foo.bar", comment: "comment" do |s|
      #     s.value "baz"
      #     s.value "qux"
      #   end
      def ruby_snippet(&block)
        @ruby_snippet ||= block
      end

      # Build the operation from arguments sent to Ruby method
      def from_ruby(*args, &block)
        options = args.last.is_a?(Hash) ? args.pop.symbolize_keys : {}
        params = ruby_params.zip(args).to_h
        new(**params, **options, &block)
      end

      private

      def inherited(klass)
        # Use params from a parent class by default (can be overloaded).
        klass.instance_variable_set(:@ruby_params, ruby_params)
        klass.instance_variable_set(:@ruby_snippet, ruby_snippet)
        super
      end
    end

    # @private
    # Ruby snippet to dump the creator
    # @return [String]
    def to_ruby
      builder = RubyBuilder.new(self.class.ruby_name)
      instance_exec(builder, &self.class.ruby_snippet)
      builder.build.rstrip
    end

    # List of attributes assigned that are assigned
    # via Ruby method parameters.
    #
    # We can use it to announce the operation to $stdout
    # like `create_foreign_key("users", "roles")`.
    def to_a
      to_h.values_at(*self.class.ruby_params)
    end

    def to_opts
      to_h.except(*self.class.ruby_params)
    end

    # @param [IO] stream
    def dump(stream)
      to_ruby&.rstrip&.lines&.each { |line| stream.print(line.indent(2)) }
    end
  end
end
