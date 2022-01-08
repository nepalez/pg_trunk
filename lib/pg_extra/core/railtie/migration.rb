# frozen_string_literal: true

module PGExtra
  # @private
  # The module goes around the ActiveRecord::Migration's `method_missing`.
  #
  # This is necessary because +ActiveRecord::Migration#method_missing+
  # forces the first argument to be a proper table name.
  #
  # In Rails migrations the first argument specifies the +table+,
  # while the +name+ of the object can be specified by option:
  #
  #    pg_extra_create_index :users, %w[id name], name: 'users_idx'
  #
  # in PGExtra the positional argument is always specify the name
  # of the the current object (type, function, table etc.):
  #
  #    pg_extra_create_index 'users_ids', table: 'users', columns: %w[id name]
  #    create_enum 'currency', values: %w[USD EUR BTC]
  #
  # With this fix we can also use the options-only syntax like:
  #
  #    pg_extra_create_enum name: 'currency', values: %w[USD EUR BTC]
  #
  # or even skip any name when it can be generated from options:
  #
  #    pg_extra_create_index do |i|
  #      i.table 'users'
  #      i.column 'id'
  #    end
  #
  module Migration
    # @param [PGExtra::Operation] klass
    def self.register(klass)
      define_method(klass.ruby_name) do |*args, &block|
        say_with_time "#{klass.ruby_name}(#{_pretty_args(*args)})" do
          connection.send(klass.ruby_name, *args, &block)
        end
      end
    end

    private

    def _pretty_args(*args)
      opts = args.last.is_a?(Hash) ? args.pop : {}
      opts = opts.map { |k, v| "#{k}: #{v.inspect}" if v.present? }.compact
      [*args.map(&:inspect), *opts].join(", ")
    end
  end
end
