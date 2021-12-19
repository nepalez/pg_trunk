# frozen_string_literal: false

module PGExtra::Operations::Views
  # @abstract
  # @private
  # Base class for operations with views
  class Base < PGExtra::Operation
    # All attributes that can be used by view-related commands
    attribute :check, :pg_extra_symbol
    attribute :force, :pg_extra_symbol
    attribute :replace_existing, :boolean
    attribute :sql_definition, :pg_extra_multiline_text
    attribute :version, :integer, aliases: :revert_to_version

    # Load missed `sql_definition` from the external file
    after_initialize { self.sql_definition ||= read_snippet_from(:views) }

    # Ensure correctness of present values
    validates :check, inclusion: %i[local cascaded], allow_nil: true
    validates :force, inclusion: %i[cascade restrict], allow_nil: true

    # Use comparison by name from pg_extra operations base class (default)
    # Support name as the only positional argument (default)

    ruby_snippet do |s|
      s.ruby_param(name.lean) if name.present?
      s.ruby_param(to: new_name.lean) if new_name.present?
      s.ruby_param(replace_existing: true) if replace_existing
      s.ruby_param(if_exists: true) if if_exists
      s.ruby_param(force: :cascade) if force == :cascade

      s.ruby_line(:version, version, from: from_version)
      s.ruby_line(:sql_definition, sql_definition, from: from_sql_definition)
      s.ruby_line(:check, check, from: from_check)
      s.ruby_line(:comment, comment, from: from_comment)
    end
  end
end
