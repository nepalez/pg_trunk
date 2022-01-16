# frozen_string_literal: false

# @!parse
#   class ActiveRecord::Migration
#     # Modify a function
#     #
#     # @param [#to_s] name (nil) The qualified name of the function
#     # @option options [Boolean] :if_exists (false) Suppress the error when the function is absent
#     # @yield [f] the block with the function's definition
#     # @yieldparam Object receiver of methods specifying the function
#     # @return [void]
#     #
#     # The operation changes the function without dropping it
#     # (which can be necessary when there are other objects
#     # using the function and you don't want to change them all).
#     #
#     # You can change any property except for the name
#     # (use `rename_function` instead) and `language`.
#     #
#     # ```ruby
#     # change_function "math.mult(int, int)" do |f|
#     #   f.volatility :immutable, from: :stable
#     #   f.parallel :safe, from: :restricted
#     #   f.security :invoker
#     #   f.leakproof true
#     #   f.strict true
#     #   f.cost 5.0
#     #   # f.rows 1 (supported for functions returning sets of rows)
#     # SQL
#     # ```
#     #
#     # The example above is not invertible because of uncertainty
#     # about the previous volatility, parallelism, and cost.
#     # To define them, use a from options (available in a block syntax only):
#     #
#     # ```ruby
#     # change_function "math.mult(a int, b int)" do |f|
#     #   f.body <<~SQL, from: <<~SQL
#     #     SELECT a * b;
#     #   SQL
#     #     SELECT min(a * b, 1);
#     #   SQL
#     #   f.volatility :immutable, from: :volatile
#     #   f.parallel :safe, from: :unsafe
#     #   f.leakproof true
#     #   f.strict true
#     #   f.cost 5.0, from: 100.0
#     # SQL
#     # ```
#     #
#     # Like in the other operations, the function can be
#     # identified by a qualified name (with types of arguments).
#     # If it has no overloaded implementations, the plain name is supported as well.
#     def change_function(name, **options, &block); end
#   end
module PGTrunk::Operations::Functions
  # @private
  class ChangeFunction < Base
    validates :force, :new_name, :language, :replace_existing, absence: true
    validate { errors.add :base, "Changes can't be blank" if changes.blank? }
    validate do
      next if if_exists || name.blank? || create_function.present?

      errors.add :base, "Function #{name.lean} can't be found"
    end

    def to_sql(server_version)
      # Use `CREATE OR REPLACE FUNCTION` to make changes
      create_function&.to_sql(server_version)
    end

    def invert
      irreversible!("if_exists: true") if if_exists
      undefined = inversion.select { |_, v| v.nil? }.keys.join(", ").presence
      raise IrreversibleMigration.new(self, nil, <<~MSG.squish) if undefined
        Undefined values to revert #{undefined}.
      MSG

      self.class.new(**inversion, name: name)
    end

    private

    def create_function
      return if name.blank?

      @create_function ||= begin
        list = CreateFunction.select { |obj| name.maybe_eq?(obj.name) }
        list.select! { |obj| name == obj.name } if list.size > 1 && name.args
        list.first&.tap do |op|
          op.attributes = { **changes, replace_existing: true }
        end
      end
    end

    def changes
      @changes ||= to_h.except(:name).reject { |_, v| v.nil? || v == "" }
    end

    def inversion
      @inversion ||= {
        body: [body, from_body],
        volatility: [volatility, from_volatility],
        parallel: [parallel, from_parallel],
        cost: [cost, from_cost],
        rows: [rows, from_rows],
        comment: [comment, from_comment],
        security: [security, (security == :invoker ? :definer : :invoker)],
        leakproof: [leakproof, !leakproof],
        strict: [strict, !strict],
      }.slice(*changes.keys).transform_values(&:last)
    end
  end
end
