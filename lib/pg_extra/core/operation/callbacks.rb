# frozen_string_literal: true

class PGExtra::Operation
  # @private
  # Enable to fulfill/generate missed attributes
  # using the `after_initialize` callback.
  #
  # The callback is invoked after the end of the normal
  # initialization and applying a block with explicit settings.
  module Callbacks
    extend ActiveSupport::Concern

    class_methods do
      def callbacks
        @callbacks ||= []
      end

      # Get or set the callback
      def after_initialize(&block)
        callbacks << block if block
      end

      private

      def inherited(klass)
        klass.instance_variable_set(:@callbacks, callbacks.dup)
        super
      end
    end

    private def initialize(*, **, &block)
      # Explicitly assign all attributes from params/options.
      super
      # Explicitly assign attributes using a block.
      block&.call(self)
      # Apply +callback+ at the very end after all explicit assignments.
      self.class.callbacks.each { |callback| instance_exec(&callback) }
    end
  end
end
