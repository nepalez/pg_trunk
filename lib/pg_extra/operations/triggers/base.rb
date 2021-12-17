# frozen_string_literal: false

module PGExtra::Operations::Triggers
  # @abstract
  # @private
  # Base class for operations with triggers
  class Base < PGExtra::Operation
    # All attributes that can be used by trigger-related commands
    attribute :columns, :pg_extra_array_of_strings, default: []
    attribute :constraint, :boolean
    attribute :events, :pg_extra_array_of_symbols, default: []
    attribute :for_each, :pg_extra_symbol
    attribute :function, :pg_extra_qualified_name
    attribute :initially, :pg_extra_symbol
    attribute :replace_existing, :boolean
    attribute :table, :pg_extra_qualified_name
    attribute :type, :pg_extra_symbol
    attribute :when, :string

    # Generate missed name of the trigger
    after_initialize { self.name = generated_name if name.blank? }
    after_initialize { self.type ||= :after if constraint }
    after_initialize { self.for_each ||= :row if constraint }

    # Ensure correctness of present values
    validates :table, presence: true
    validates :for_each, inclusion: { in: %i[row statement] }, allow_nil: true
    validates :initially, inclusion: { in: %i[immediate deferred] }, allow_nil: true
    validates :type, inclusion: { in: %i[after before instead_of] }, allow_nil: true
    validates :events,
              inclusion: { in: %i[insert update delete truncate] },
              allow_blank: true
    validate do
      next if name.blank?

      errors.add :name, "can't have a schema" unless name.current_schema?
    end
    validate do
      next unless initially && !constraint

      errors.add :initially, "can be used for constraints only"
    end
    validate do
      next unless columns.present? && type == :instead_of

      errors.add :columns,
                 "can be defined for before/after update triggers only"
    end
    validate do
      next unless constraint && type != :after && for_each != :row

      errors.add :base, "Only AFTER EACH ROW triggers can be constraints"
    end
    validate do
      next unless self.when && type == :instead_of

      errors.add :when, "is not supported for INSTEAD OF triggers"
    end
    validate do
      next if new_name.blank? || new_name.current_schema?

      errors.add :base, "New name can't specify the schema"
    end

    # triggers are ordered by table and name
    def <=>(other)
      return unless other.is_a?(self.class)

      result = table <=> other.table
      result.zero? ? super : result
    end

    # Support `table` and `name` in positional arguments.
    # @example
    #   add_trigger :users, :my_trigger, **opts
    ruby_params :table, :name

    ruby_snippet do |s|
      s.ruby_param(table.lean) if table.present?
      s.ruby_param(name.lean) if custom_name?
      s.ruby_param(to: new_name.lean) if custom_name?(new_name)
      s.ruby_param(if_exists: true) if if_exists
      s.ruby_param(:replace_existing, true) if replace_existing

      s.ruby_line(:function, function.lean) if function.present?
      s.ruby_line(:when, self.when)
      s.ruby_line(:constraint, true) if constraint
      s.ruby_line(:for_each, for_each) if for_each&.== :row
      s.ruby_line(:type, type) if type.present?
      s.ruby_line(:events, events) if events.present?
      s.ruby_line(:columns, columns) if columns.present?
      s.ruby_line(:initially, initially)
      s.ruby_line(:comment, comment, from: from_comment)
    end

    private

    # Generate the name of the trigger using the essential options
    # @return [PGExtra::QualifiedName]
    def generated_name
      return @generated_name if instance_variable_defined?(:@generated_name)

      @generated_name = begin
        return if [table, function, type, events].any?(&:blank?)

        key_options = to_h.reject { |_, v| v.blank? }.slice(
          :table, :function, :for_each, :type, :events,
        )
        identifier = "#{table.lean}_#{key_options}_tg"
        hashed_identifier = Digest::SHA256.hexdigest(identifier).first(10)
        PGExtra::QualifiedName.wrap("tg_rails_#{hashed_identifier}")
      end
    end

    def custom_name?(qname = name)
      qname&.differs_from?(/^tg_rails_\w{10}$/)
    end
  end
end
