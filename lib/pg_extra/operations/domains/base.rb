# frozen_string_literal: false

module PGExtra::Operations::Domains
  # @abstract
  # @private
  # Base class for operations with domain types
  class Base < PGExtra::Operation
    # All attributes that can be used by domain-related commands
    attribute :collation, :pg_extra_qualified_name
    attribute :constraints, :pg_extra_array_of_hashes, default: []
    attribute :default_sql, :pg_extra_multiline_text
    attribute :null, :boolean
    attribute :type, :pg_extra_qualified_name, aliases: :as

    # Populate constraints from a block
    def constraint(check, name: nil)
      constraints << Constraint.new(check: check, name: name)
    end

    # Wrap constraint definitions to value objects
    after_initialize { constraints.map! { |c| Constraint.build(c) } }

    validates :if_not_exists, absence: true
    validates :name, presence: true
    validates :constraints, "PGExtra/all_items_valid": true, allow_nil: true

    # Use comparison by name from pg_extra operations base class (default)
    # Support name as the only positional argument (default)

    ruby_snippet do |s|
      s.ruby_param(name.lean) if name.present?
      s.ruby_param(as: type.lean) if type.present?
      s.ruby_param(to: new_name) if new_name.present?
      s.ruby_param(if_exists: true) if if_exists
      s.ruby_param(force: :cascade) if force == :cascade

      s.ruby_line(:collation, collation.lean) if collation.present?
      s.ruby_line(:default_sql, default_sql, from: from_default_sql) if default_sql
      s.ruby_line(:null, false) if null == false
      constraints.sort_by(&:name).each do |c|
        s.ruby_line(:constraint, c.check, **c.opts)
      end
      s.ruby_line(:comment, comment, from: from_comment) if comment
    end
  end
end
