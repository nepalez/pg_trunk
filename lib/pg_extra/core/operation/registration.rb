# frozen_string_literal: true

class PGExtra::Operation
  # Invoke all the necessary definitions
  # in the modules included to Rails via Railtie
  module Registration
    extend ActiveSupport::Concern

    class_methods do
      def from_sql(&block)
        super.tap { register_dumper if block }
      end

      def generates_object(name = nil)
        super.tap { register_generator if name }
      end

      def method_added(name)
        super
      ensure
        register_operation if name == :to_sql
        register_inversion if name == :invert
      end

      private

      def register_operation
        # Add the method to statements as an entry point
        PGExtra::Statements.register(self)
        # Add the shortcut to migration go get away with checking
        # of the first parameter which could be NOT a table name.
        PGExtra::Migration.register(self)
        # Record the direct operation
        PGExtra::CommandRecorder.register(self)
      end

      def register_inversion
        # Record the inversion of the operation
        PGExtra::CommandRecorder.register_inversion(self)
      end

      def register_dumper
        PGExtra::SchemaDumper.register(self)
      end

      def register_generator
        # skip registration in the runtime
        return unless const_defined?("PGExtra::Generators")

        PGExtra::Generators.register(self)
      end
    end
  end
end
