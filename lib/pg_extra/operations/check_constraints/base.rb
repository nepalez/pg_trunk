# frozen_string_literal: false

module PGExtra::Operations::CheckConstraints
  # @abstract
  # @private
  # Base class for operations with check constraints
  class Base < PGExtra::Operation
    # All attributes that can be used by check-related commands
    attribute :expression, :string
    attribute :inherit, :boolean, default: true
    attribute :table, :pg_extra_qualified_name

    # Generate missed name from table & expression
    after_initialize { self.name = generated_name if name.blank? }

    # Ensure correctness of present values
    # The table must be defined because the name only
    # is not enough to identify the constraint.
    validates :if_not_exists, absence: true
    validates :table, presence: true

    # By default foreign keys are sorted by tables and names.
    def <=>(other)
      return unless other.is_a?(self.class)

      result = table <=> other.table
      result.zero? ? super : result
    end

    # Support `table` and `expression` in positional arguments
    # @example
    #   add_check_constraint :users, "length(phone) == 10", **opts
    ruby_params :table, :expression

    # Snippet to be used in all operations with check constraints
    ruby_snippet do |s|
      s.ruby_param(table.lean) if table.present?
      s.ruby_param(expression) if expression.present?
      s.ruby_param(if_exists: true) if if_exists
      s.ruby_param(inherit: false) if inherit&.== false
      s.ruby_param(name: name.lean) if custom_name?
      s.ruby_param(to: new_name.lean) if custom_name?(new_name)
      s.ruby_param(comment: comment) if comment.present?
    end

    private

    # *************************************************************************
    # Helpers for operation definitions
    # *************************************************************************

    def generated_name
      return @generated_name if instance_variable_defined?(:@generated_name)

      @generated_name = begin
        return if table.blank? || expression.blank?

        PGExtra::QualifiedName.new(
          nil,
          PGExtra.database.check_constraint_name(table.lean, expression),
        )
      end
    end

    def custom_name?(qname = name)
      qname&.differs_from?(/^chk_rails_\w+$/)
    end
  end
end
