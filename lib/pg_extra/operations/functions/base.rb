# frozen_string_literal: false

module PGExtra::Operations::Functions
  # @abstract
  # @private
  # Base class for operations with functions
  class Base < PGExtra::Operation
    # All attributes that can be used by function-related commands
    attribute :body, :pg_extra_multiline_text
    attribute :cost, :float
    attribute :language, :pg_extra_lowercase_string
    attribute :leakproof, :boolean
    attribute :parallel, :pg_extra_symbol
    attribute :replace_existing, :boolean
    attribute :rows, :integer
    attribute :security, :pg_extra_symbol
    attribute :strict, :boolean
    attribute :volatility, :pg_extra_symbol
    attribute :version, :pg_extra_multiline_text

    # Ensure correctness of present values
    validates :if_not_exists, absence: true
    validates :volatility, inclusion: { in: %i[volatile stable immutable] }, allow_nil: true
    validates :security, inclusion: { in: %i[invoker definer] }, allow_nil: true
    validates :parallel, inclusion: { in: %i[safe unsafe] }, allow_nil: true
    validates :cost, numericality: { greater_than: 0 }, allow_nil: true
    validates :rows, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
    validate do
      errors.add :body, "can't contain SQL injection with $$" if body&.include?("$$")
    end

    # Use comparison by name from pg_extra operations base class (default)
    # Support name as the only positional argument (default)

    ruby_snippet do |s|
      s.ruby_param(name.lean) if name.present?
      s.ruby_param(to: new_name.lean) if new_name.present?
      s.ruby_param(if_exists: true) if if_exists
      s.ruby_param(force: :cascade) if force == :cascade
      s.ruby_param(replace_existing: true) if replace_existing

      s.ruby_line(:language, language) if language&.!= "sql"
      s.ruby_line(:volatility, volatility, from: from_volatility) if volatility.present?
      s.ruby_line(:leakproof, true) if leakproof
      s.ruby_line(:strict, true) if strict
      s.ruby_line(:security, security) if security.present?
      s.ruby_line(:parallel, parallel, from: from_parallel) unless parallel.nil?
      s.ruby_line(:cost, cost, from: from_cost) if cost.present?
      s.ruby_line(:rows, rows, from: from_rows) if rows.present?
      s.ruby_line(:body, body, from: from_body) if body.present?
      s.ruby_line(:comment, comment, from: from_comment) if comment
    end
  end
end
