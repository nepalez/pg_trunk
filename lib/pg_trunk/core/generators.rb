# frozen_string_literal: false

require "rails/generators"
require "rails/generators/active_record"

# @private
# @abstract
# Module to build object-specific generators
module PGTrunk::Generators
  extend ActiveSupport::Concern

  class << self
    # Add new generator for given operation
    # @param [Class < PGTrunk::Operation] operation
    def register(operation)
      klass = build_generator(operation)
      class_name = klass.name.split("::").last.to_sym
      remove_const(class_name) if const_defined?(class_name)
      const_set(class_name, klass)
    end

    # rubocop: disable Metrics/MethodLength
    def build_generator(operation)
      Class.new(Rails::Generators::NamedBase) do
        include Rails::Generators::Migration
        include PGTrunk::Generators

        # Add the same arguments as in ruby method
        operation.ruby_params.each do |name|
          argument(name, **operation.attributes[name])
        end

        # Add the same options as in ruby method
        operation.attributes.except(*operation.ruby_params).each do |name, opts|
          class_option(name, **opts)
        end

        # The only command of the generator is to create a migration file
        create_command(:create_migration_file)
      end
    end
    # rubocop: enable Metrics/MethodLength
  end

  class_methods do
    # @!attribute [r] fetcher The module including +PGTrunk::BaseFetcher+
    attr_accessor :operation

    # The name of the generated object like `foreign_key`
    # for the `add_foreign_key` operation so that the command
    #
    #   rails g foreign_key 'users', 'roles'
    #
    # to build the migration containing
    #
    #   def change
    #     add_foreign_key 'users', 'roles'
    #   end
    #
    def object_name
      @object_name ||= operation.object.singularize
    end

    # Use the name of the object as a name of the generator class
    def name
      @name ||= "PGTrunk::Generators::#{object_name.camelize}"
    end

    # The name of the operation to be added to the migration
    def operation_name
      @operation_name ||= operation.ruby_name
    end

    # Ruby handler to add positional arguments to options
    def handle(*arguments, **options)
      options.ruby_params.zip(arguments).merge(options)
    end

    def next_migration_number(dir)
      ::ActiveRecord::Generators::Base.next_migration_number(dir)
    end
  end

  def create_migration_file
    file_name = "db/migrate/#{migration_number}_#{migration_name}.rb"
    file = create_migration(file_name, nil, {}) do
      <<~RUBY
        # frozen_string_literal: true

        class #{migration_name.camelize} < #{migration_base}
          def change
            #{command}
          end
        end
      RUBY
    end
    Rails::Generators.add_generated_file(file)
  end

  private

  def current_version
    return @current_version if instance_variable_defined?(:@current_version)

    @current_version = nil
    return unless ActiveRecord::Migration.respond_to?(:current_version)

    @current_version = ActiveRecord::Migration.current_version
  end

  # Build the name of the migration from given params like:
  #
  #   rails g foreign_key 'users', 'roles'
  #
  # to generate the migration named as:
  #
  #   class AddForeignKeyUsersRoles < ::ActiveRecord::Migration[6.2]
  #     # ...
  #   end
  def migration_name
    @migration_name ||= [
      self.class.operation_name,
      *(self.class.operation.ruby_params.map { |p| send(p) }),
    ].join("_")
  end

  def migration_base
    @migration_base ||= "::ActiveRecord::Migration".tap do |mb|
      next if Rails::Version::MAJOR < "5"

      mb << "[#{current_version}]" if current_version.present?
    end
  end

  def command
    opts = self.class.handle(*arguments, **options.symbolize_keys)
    operation = self.class.operation.new(opts)
    operation.to_ruby.indent(4).strip
  end
end
