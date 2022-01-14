# frozen_string_literal: false

module PGTrunk::Operations::Procedures
  # @abstract
  # @private
  # Base class for operations with procedures
  class Base < PGTrunk::Operation
    # All attributes that can be used by procedure-related commands
    attribute :body, :pg_trunk_multiline_text
    attribute :language, :pg_trunk_lowercase_string
    attribute :replace_existing, :boolean
    attribute :security, :pg_trunk_symbol

    # Ensure correctness of present values
    validates :security, inclusion: { in: %i[invoker definer] }, allow_nil: true
    validates :force, :if_not_exists, absence: true
    validate do
      errors.add :body, "can't contain SQL injection with $$" if body&.include?("$$")
    end

    # Use comparison by name from pg_trunk operations base class (default)
    # Support name as the only positional argument (default)

    ruby_snippet do |s|
      s.ruby_param(name.lean) if name.present?
      s.ruby_param(to: new_name.lean) if new_name.present?
      s.ruby_param(if_exists: true) if if_exists
      s.ruby_param(replace_existing: true) if replace_existing

      s.ruby_line(:language, language.downcase) if language&.!= "sql"
      s.ruby_line(:security, security) if security&.!= :invoker
      s.ruby_line(:body, body, from: from_body)
      s.ruby_line(:comment, comment, from: from_comment)
    end

    private

    def check_version!(version)
      raise "Procedures are supported in PostgreSQL v11+" if version < "11"
    end
  end
end
