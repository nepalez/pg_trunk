# frozen_string_literal: true

module PGExtra
  # @private
  # The module record commands done during a migration.
  module CommandRecorder
    # @param [PGExtra::Operation] klass
    def self.register(klass)
      define_method(klass.ruby_name) do |*args, &block|
        record(klass.ruby_name, args, &block)
      end
    end

    # @param [PGExtra::Operation] klass
    def self.register_inversion(klass)
      define_method(klass.ruby_iname) do |args, &block|
        original = klass.from_ruby(*args, &block)
        inverted = original.invert!
        # for example (skip_inversion(:validate_foreign_key))
        return [:skip_inversion, [klass.ruby_name]] unless inverted

        # list of attributes `to_a` is added for reporting to stdout
        params = inverted.to_a
        opts = inverted.to_opts
        params << opts if opts.present?
        [inverted.class.ruby_name, params]
      end
    end
  end
end
