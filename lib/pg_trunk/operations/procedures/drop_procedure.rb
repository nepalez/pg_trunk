# frozen_string_literal: false

# @!parse
#   class ActiveRecord::Migration
#     # Drop a procedure
#     #
#     # @param [#to_s] name (nil)
#     #   The qualified name of the procedure with arguments and returned value type
#     # @option options [Boolean] :if_exists (false) Suppress the error when the procedure is absent
#     # @option options [#to_s] :language ("sql") The language (like "sql" or "plpgsql")
#     # @option options [#to_s] :body (nil) The body of the procedure
#     # @option options [Symbol] :security (:invoker) Define the role under which the procedure is invoked
#     #   Supported values: :invoker (default), :definer
#     # @option options [#to_s] :comment The description of the procedure
#     # @yield [p] the block with the procedure's definition
#     # @yieldparam Object receiver of methods specifying the procedure
#     # @return [void]
#     #
#     # A procedure can be dropped by a plain name:
#     #
#     # ```ruby
#     # drop_procedure "set_foo"
#     # ```
#     #
#     # If several overloaded procedures have the name,
#     # then you must specify the signature having
#     # types of attributes at least:
#     #
#     # ```ruby
#     # drop_procedure "set_foo(int)"
#     # ```
#     #
#     # In both cases above the operation is irreversible. To make it
#     # inverted you have to provide a full signature along with
#     # the body definition. The other options are supported as well:
#     #
#     # ```ruby
#     # drop_procedure "metadata.set_foo(a int)" do |p|
#     #   p.language "sql" # (default)
#     #   p.body <<~SQL
#     #     SET foo = a
#     #   SQL
#     #   p.security :invoker # (default), also :definer
#     #   p.comment "Multiplies 2 integers"
#     # SQL
#     # ```
#     #
#     # The operation can be called with `if_exists` option. In this case
#     # it would do nothing when no procedure existed.
#     #
#     # ```ruby
#     # drop_procedure "metadata.set_foo(a int)", if_exists: true
#     # ```
#     #
#     # Notice, that this option make the operation irreversible because of
#     # uncertainty about the previous state of the database.
#     def drop_procedure(name, **options, &block); end
#   end
module PGTrunk::Operations::Procedures
  # @private
  class DropProcedure < Base
    validates :replace_existing, :new_name, absence: true

    def to_sql(version)
      check_version!(version)

      sql = "DROP PROCEDURE"
      sql << " IF EXISTS" if if_exists
      sql << " #{name.to_sql};"
    end

    def invert
      irreversible!("if_exists: true") if if_exists
      CreateProcedure.new(**to_h)
    end
  end
end
