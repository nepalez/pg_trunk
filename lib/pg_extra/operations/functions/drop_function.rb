# frozen_string_literal: false

# @!method ActiveRecord::Migration#drop_function(name, **options, &block)
# Drop a function
#
# @param [#to_s] name (nil)
#   The qualified name of the function with arguments and returned value type
# @option [Boolean] :if_exists (false) Suppress the error when the function is absent
# @option [Symbol] :force (:restrict) How to process dependent objects
#   Supported values: :restrict (default), :cascade
# @option [#to_s] :language ("sql") The language (like "sql" or "plpgsql")
# @option [#to_s] :body (nil) The body of the function
# @option [Symbol] :volatility (:volatile) The volatility of the function.
#   Supported values: :volatile (default), :stable, :immutable
# @option [Symbol] :parallel (:unsafe) The safety of parallel execution.
#   Supported values: :unsafe (default), :restricted, :safe
# @option [Symbol] :security (:invoker) Define the role under which the function is invoked
#   Supported values: :invoker (default), :definer
# @option [Boolean] :leakproof (false) If the function is leakproof
# @option [Boolean] :strict (false) If the function is strict
# @option [Float] :cost (nil) The cost estimation for the function
# @option [Integer] :rows (nil) The number of rows returned by a function
# @option [#to_s] :comment The description of the function
# @yield [Proc] the block with the function's definition
# @yieldparam The receiver of methods specifying the function
#
# A function can be dropped by a plain name:
#
#   drop_function "multiply"
#
# If several overloaded functions have the name,
# then you must specify the signature having
# types of attributes at least:
#
#   drop_function "multiply(int, int)"
#
# In both cases above the operation is irreversible. To make it
# inverted you have to provide a full signature along with
# the body definition. The other options are supported as well:
#
#   drop_function "math.mult(a int, b int) int" do |f|
#     f.language "sql" # (default)
#     f.body <<~SQL
#       SELECT a * b;
#     SQL
#     f.volatility :immutable # :stable, :volatile (default)
#     f.parallel :safe        # :restricted, :unsafe (default)
#     f.security :invoker     # (default), also :definer
#     f.leakproof true
#     f.strict true
#     f.cost 5.0
#     # f.rows 1 (supported for functions returning sets of rows)
#     f.comment "Multiplies 2 integers"
#   end
#
# The operation can be called with `if_exists` option. In this case
# it would do nothing when no function existed.
#
#   drop_function "math.multiply(integer, integer)", if_exists: true
#
# Another operation-specific option `force: :cascade` enables
# to drop silently any object depending on the function.
#
#   drop_function "math.multiply(integer, integer)", force: :cascade
#
# Both options make the operation irreversible because of
# uncertainty about the previous state of the database.

module PGExtra::Operations::Functions
  # @private
  class DropFunction < Base
    validates :replace_existing, :new_name, absence: true

    def to_sql(_version)
      sql = "DROP FUNCTION"
      sql << " IF EXISTS" if if_exists
      sql << " #{name.to_sql}"
      sql << " CASCADE" if force == :cascade
      sql << ";"
    end

    def invert
      irreversible!("if_exists: true") if if_exists
      irreversible!("force: :cascade") if force == :cascade
      CreateFunction.new(**to_h.except(:force))
    end
  end
end
