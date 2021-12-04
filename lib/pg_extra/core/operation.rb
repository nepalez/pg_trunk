# frozen_string_literal: false

require_relative "operation/callbacks"
require_relative "operation/attributes"

module PGExtra
  # @api private
  # Base class for operations.
  # Inherit this class to define new operation.
  class Operation
    include Callbacks
    include Attributes

    attribute :comment, :string
    attribute :force, :pg_extra_symbol
    attribute :if_exists, :boolean
    attribute :if_not_exists, :boolean
    attribute :name, :pg_extra_qualified_name
    attribute :new_name, :pg_extra_qualified_name, aliases: :to
    attribute :oid, :integer
    attribute :version, :integer, aliases: :revert_to_version

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
