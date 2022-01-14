# frozen_string_literal: false

require_relative "operation/callbacks"
require_relative "operation/attributes"
require_relative "operation/generators"
require_relative "operation/validations"
require_relative "operation/inversion"
require_relative "operation/ruby_builder"
require_relative "operation/ruby_helpers"
require_relative "operation/sql_helpers"
require_relative "operation/registration"

module PGTrunk
  # @private
  # Base class for operations.
  # Inherit this class to define new operation.
  class Operation
    include Callbacks
    include Attributes
    include Generators
    include Comparable
    include Validations
    include Inversion
    include RubyHelpers
    include SQLHelpers
    include Registration

    attribute :comment, :string, desc: \
              "The comment to the object"
    attribute :force, :pg_trunk_symbol, desc: \
              "How to process dependent objects"
    attribute :if_exists, :boolean, desc: \
              "Don't fail if the object is absent"
    attribute :if_not_exists, :boolean, desc: \
              "Don't fail if the object is already present"
    attribute :name, :pg_trunk_qualified_name, desc: \
              "The qualified name of the object"
    attribute :new_name, :pg_trunk_qualified_name, aliases: :to, desc: \
              "The new name of the object to rename to"
    attribute :oid, :integer, desc: \
              "The oid of the database object"
    attribute :version, :integer, aliases: :revert_to_version, desc: \
              "The version of the SQL snippet"

    validates :name, presence: true
    validates :new_name, "PGTrunk/difference": { from: :name }, allow_nil: true
    validates :force, inclusion: { in: %i[cascade restrict] }, allow_nil: true

    # By default ruby methods take the object name as a positional argument.
    ruby_params :name

    protected

    # Define the order of objects
    # @param [PGTrunk::Operation]
    # @return [-1, 0, 1, nil]
    def <=>(other)
      name <=> other.name if other.is_a?(self.class)
    end

    private

    # Helper to read a versioned snippet for a specific
    # kind of objects
    def read_snippet_from(kind)
      return if kind.blank? || name.blank? || version.blank?

      filename = format(
        "db/%<kind>s/%<name>s_v%<version>02d.sql",
        kind: kind.to_s.pluralize,
        name: name.routine,
        version: version,
      )
      filepath = Rails.root.join(filename)
      File.read(filepath).sub(/;\s*$/, "")
    end
  end
end
