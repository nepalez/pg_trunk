# frozen_string_literal: false

module PGTrunk::Operations::Rules
  # @abstract
  # @private
  # Base class for operations with rules
  class Base < PGTrunk::Operation
    attribute :command, :string
    attribute :event, :pg_trunk_symbol
    attribute :kind, :pg_trunk_symbol
    attribute :replace_existing, :boolean
    attribute :table, :pg_trunk_qualified_name
    attribute :where, :string

    # Generate missed name from table & expression
    after_initialize { self.name = generated_name if name.blank? }

    # Ensure correctness of present values
    # The table must be defined because the name only
    # is not enough to identify the constraint.
    validates :if_not_exists, absence: true
    validates :table, :name, presence: true
    validates :kind, inclusion: { in: %i[instead also] }, allow_nil: true
    validates :event, inclusion: { in: %i[insert update delete] }, allow_nil: true

    # By default rules are sorted by tables and names.
    def <=>(other)
      return unless other.is_a?(self.class)

      result = table <=> other.table
      result.zero? ? super : result
    end

    # Support `table` and `name` in positional arguments
    # @example
    #   create_rule :users, "_do_nothing"
    ruby_params :table, :name

    # Snippet to be used in all operations with rules
    ruby_snippet do |s|
      s.ruby_param(table.lean) if table.present?
      s.ruby_param(name.name) if custom_name?
      s.ruby_param(if_exists: true) if if_exists
      s.ruby_param(replace_existing: true) if replace_existing
      s.ruby_param(force: :cascade) if force == :cascade

      s.ruby_line(:event, event) if event.present?
      s.ruby_line(:kind, :instead) if kind == :instead
      s.ruby_line(:where, where) if where.present?
      s.ruby_line(:command, command) if command.present?
      s.ruby_line(:comment, comment) if comment.present?
    end

    private

    # *************************************************************************
    # Helpers for operation definitions
    # *************************************************************************

    def generated_name
      return @generated_name if instance_variable_defined?(:@generated_name)

      @generated_name = begin
        return if table.blank? || event.blank?

        key_options = { event: event, kind: (kind || :also) }
        identifier = "#{table.lean}_#{key_options}_rule"
        hashed_identifier = Digest::SHA256.hexdigest(identifier).first(10)
        PGTrunk::QualifiedName.wrap("rule_rails_#{hashed_identifier}")
      end
    end

    def custom_name?(qname = name)
      qname&.differs_from?(/^rule_rails_\w+$/)
    end
  end
end
