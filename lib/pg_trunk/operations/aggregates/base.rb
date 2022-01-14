# frozen_string_literal: false

module PGTrunk::Operations::Aggregates
  # @abstract
  # Base class for operations with aggregates
  class Base < PGTrunk::Operation
    # All attributes that can be used by aggregate-related commands
    attribute :force, :pg_trunk_symbol
    attribute :if_exists, :boolean
    attribute :into, :pg_trunk_qualified_name
    attribute :replace_existing, :boolean
    attribute :parallel, :pg_trunk_symbol
    attribute :hypothetical, :boolean
    # state/final functions definition
    attribute :sfunc, :string
    attribute :stype, :string
    attribute :sspace, :integer
    attribute :ffunc, :string
    attribute :fextra, :boolean
    attribute :fmodify, :pg_trunk_symbol
    attribute :initcond, :string
    # moving state/final functions definition
    attribute :msfunc, :string
    attribute :minvfunc, :string
    attribute :mstype, :string
    attribute :msspace, :integer
    attribute :mfinalfunc, :string
    attribute :mfinalfunc_extra, :boolean
    attribute :mfinalfunc_modify, :pg_trunk_symbol
    attribute :minitcond, :string
    # serial/deserial functions definition
    attribute :serial_func, :string
    attribute :deserial_func, :string
    # combine function definition (for partial aggregation)
    attribute :combine_function, :string
    # sorting/ordering
    attribute :sort_operator, :string
    attribute :order_by, :string

    # Methods to assign settings in a block

    # Define state function in a block
    def state_function(name, &block)
      func = StateFunction.new(name, &block)
      self.sfunc = func.name
      self.stype = func.type
      self.sspace = func.space
      self.ffunc = func.final
      self.fextra = func.extra
      self.fmodify = func.modify
      self.initcond = func.initial
    end

    # Define moving state functions in a block
    def moving_state_function(name, &block)
      func = StateFunction.new(name, &block)
      self.msfunc = func.name
      self.minvfunc = func.inverse
      self.mstype = func.type
      self.msspace = func.space
      self.mfinalfunc = func.final
      self.mfinalfunc_extra = func.extra
      self.mfinalfunc_modify = func.modify
      self.minitcond = func.initial
    end

    # Define serialization
    def serialization_function(name, &block)
      func = StateFunction.new(name, &block)
      self.serial_func = func.name
      self.deserial_func = func.inverse
    end

    # Ensure correctness of present values
    validates :name, presence: true
    validates :force, inclusion: { in: %i[cascade restrict] }, allow_nil: true
    validates :fmodify, :mfinalfunc_modify,
              inclusion: { in: %i[read_only shareable read_write] },
              allow_nil: true
    validates :parallel,
              inclusion: { in: %i[safe restricted unsafe] },
              allow_nil: true
    validate do
      next if [minvfunc, mstype, msspace, mfinalfunc, minitcond].all?(&:blank?)

      errors.add :msfunc, :blank if msfunc.blank?
    end
    validate do
      next if [mfinalfunc_extra, mfinalfunc_modify].all?(&:blank?)

      errors.add :mfinalfunc, :blank if mfinalfunc.blank?
    end
    validate do
      next if deserial_func.blank?

      errors.add :serial_func, :blank if serial_func.blank?
    end
    validate do
      next if [msfunc, serial_func, combine_function].all?(&:blank?)

      errors.add :hypothetical, :present if hypothetical.present?
    end
    validate do
      case hypothetical.blank?
      when true then errors.add :order_by, :present if order_by.present?
      else errors.add :sort_operator, :present if sort_operator.present?
      end
    end
    validate do
      next if name.blank?

      errors.add :name, "must have arguments" if name.args.blank?
      errors.add :name, "can't have returned value" if name.returns.present?
    end

    # Use comparison by name from pg_trunk operations base class (default)
    # Support name as the only positional argument (default)

    ruby_snippet do |s|
      s.ruby_param(name.lean) if name.present?
      s.ruby_param(replace_existing: true) if replace_existing
      s.ruby_param(if_exists: true) if if_exists
      s.ruby_param(force: :cascade) if force == :cascade
      s.ruby_param(to: into.lean) if into.present?
      s.ruby_line(:order_by) if order_by.present?
      if sfunc.present?
        s.ruby_line(:state_function, sfunc, **{ extra: fextra }.compact) do |f|
          f.ruby_line(:modify, fmodify) if fmodify&.!= :read_only
          f.ruby_line(:type, stype) if stype.present?
          f.ruby_line(:initial, initcond) if initcond.present?
          f.ruby_line(:final, ffunc) if ffunc.present?
          f.ruby_line(:space, sspace.to_i) if sspace&.positive?
        end
      end
      if msfunc.present?
        s.ruby_line(:moving_state_function, msfunc, **{ extra: mfinalfunc_extra }.compact) do |f|
          f.ruby_line(:modify, mfinalfunc_modify) if mfinalfunc_modify&.!= :read_only
          f.ruby_line(:type, mstype) if mstype.present?
          f.ruby_line(:initial, minitcond) if minitcond.present?
          f.ruby_line(:final, mfinalfunc) if mfinalfunc.present?
          f.ruby_line(:inverse, minvfunc) if minvfunc.present?
          f.ruby_line(:space, msspace.to_i) if msspace&.positive?
        end
      end
      if serial_func.present?
        s.ruby_line(:serial_function, serial_func) do |f|
          f.ruby_line(:inverse, deserial_func) if deserial_func.present?
        end
      end
      s.ruby_line(:combine_function, combine_function) if combine_function.present?
      s.ruby_line(:sort_operator, sort_operator) if sort_operator.present?
      s.ruby_line(:parallel, parallel) if parallel&.!= :unsafe
      s.ruby_line(:hypothetical, true) if hypothetical
      s.ruby_line(:comment, comment) if comment.present?
    end
  end
end
