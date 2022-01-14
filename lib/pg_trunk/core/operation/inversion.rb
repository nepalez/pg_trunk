# frozen_string_literal: true

class PGTrunk::Operation
  # @private
  # The exception to be thrown when reversed migration isn't valid
  class IrreversibleMigration < ActiveRecord::IrreversibleMigration
    private

    def initialize(operation, inversion, *messages)
      msg = "#{header(operation)}#{inverted(inversion)} #{footer(messages)}"
      super(msg.strip)
    end

    def header(operation)
      <<~MSG
        This migration uses the operation:

          #{operation.to_ruby.indent(2).strip}

      MSG
    end

    def inverted(inversion)
      return "which is not automatically reversible" unless inversion

      <<~MSG.strip
        whose inversion would be like:

          #{inversion.to_ruby.indent(2).strip}

        which is invalid
      MSG
    end

    def footer(messages)
      reasons = <<~REASONS.strip if messages.any?
        for the following reasons:

        #{messages.map { |m| "- #{m}" }.join("\n")}
      REASONS

      <<~MSG.strip
        #{reasons}

        To make the migration reversible you can either:
        1. Define #up and #down methods in place of the #change method.
        2. Use the #reversible method to define reversible behavior.
      MSG
    end
  end

  # @private
  # Enable operations to be invertible
  module Inversion
    # @private
    def invert!
      invert&.tap do |i|
        i.valid? || raise(IrreversibleMigration.new(self, i, *i.error_messages))
      end
    end

    # @private
    def irreversible!(option)
      raise IrreversibleMigration.new(self, nil, <<~MSG.squish)
        The operation with the `#{option}` option cannot be reversed
          due to uncertainty of the previous state of the database.
      MSG
    end
  end
end
