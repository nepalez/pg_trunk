# frozen_string_literal: true

module PGTrunk
  # @private
  # The module adds commands to execute DDL operations in PostgreSQL.
  module Statements
    # @param [PGTrunk::Operation] klass
    def self.register(klass)
      define_method(klass.ruby_name) do |*args, &block|
        operation = klass.from_ruby(*args, &block)
        operation.validate!
        PGTrunk.database.execute_operation(operation)
      end
    end

    # A command does nothing when a unidirectional command is inverted
    # (for example, when a foreign key validation is inverted).
    # This case is different from those when an inversion cannot be made.
    def skip_inversion(*); end
  end
end
