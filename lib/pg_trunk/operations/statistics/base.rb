# frozen_string_literal: false

module PGTrunk::Operations::Statistics
  # @abstract
  # @private
  # Base class for operations with check constraints
  class Base < PGTrunk::Operation
    # All attributes that can be used by statistics-related commands
    attribute :columns, :pg_trunk_array_of_strings, default: []
    attribute :expressions, :pg_trunk_array_of_strings, default: []
    attribute :kinds, :pg_trunk_array_of_symbols, default: []
    attribute :table, :pg_trunk_qualified_name

    # Methods to populate multivariable attributes from a block

    def expression(text)
      expressions << text.strip
    end

    def column(name)
      columns << name.strip
    end

    # Generate missed name from table & expression
    after_initialize { self.name ||= generated_name }
    after_initialize { expressions&.map!(&:strip) }

    # Ensure correctness of present values
    # The table must be defined because the name only
    # is not enough to identify the constraint.
    validates :name, presence: true
    validate do
      next if (kinds - %i[ndistinct dependencies mcv]).none?

      errors.add :kinds, :invalid
    end
    validate do
      next unless columns.blank? && expressions.size == 1

      errors.add :kinds, :present if kinds.present?
    end
    validate do
      next if expressions.present?

      errors.add :base, "Add more columns or expressions" if columns.size == 1
    end

    # By default foreign keys are sorted by names.
    # Support `table` only in positional arguments.

    # Snippet to be used in all operations with check constraints
    ruby_snippet do |s|
      s.ruby_param(name.lean) if custom_name?
      s.ruby_param(to: new_name.lean) if new_name.present?
      s.ruby_param(if_not_exists: true) if if_not_exists
      s.ruby_param(if_exists: true) if if_exists
      s.ruby_param(force: :custom) if force == :custom

      s.ruby_line(:table, table.lean) if table.present?
      if columns.size > 3
        columns.sort.each { |column| s.ruby_line(:column, column) }
      elsif columns.present?
        s.ruby_line(:columns, *columns.sort)
      end
      expressions.sort.each { |value| s.ruby_line(:expression, value) }
      s.ruby_line(:kinds, *kinds.sort) if kinds.present?
      s.ruby_line(:comment, comment) if comment.present?
    end

    private

    def generated_name
      return if table.blank? || parts.blank?

      @generated_name ||= begin
        key_options = { kinds: kinds, parts: parts }
        identifier = "#{table.lean}_#{key_options}_stat"
        hashed_identifier = Digest::SHA256.hexdigest(identifier).first(10)
        PGTrunk::QualifiedName.wrap("stat_rails_#{hashed_identifier}")
      end
    end

    def custom_name?(qname = name)
      qname&.differs_from?(/^stat_rails_\w+$/)
    end

    def parts
      @parts ||= [
        *columns.reject(&:blank?).map(&:inspect),
        *expressions.reject(&:blank?).map { |ex| "(#{ex})" },
      ]
    end
  end
end
