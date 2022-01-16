# frozen_string_literal: false

# @!parse
#   class ActiveRecord::Migration
#     # Create a function
#     #
#     # @param [#to_s] name (nil)
#     #   The qualified name of the function with arguments and returned value type
#     # @option [Boolean] :replace_existing (false) If the function should overwrite an existing one
#     # @option [#to_s] :language ("sql") The language (like "sql" or "plpgsql")
#     # @option [#to_s] :body (nil) The body of the function
#     # @option [Symbol] :volatility (:volatile) The volatility of the function.
#     #   Supported values: :volatile (default), :stable, :immutable
#     # @option [Symbol] :parallel (:unsafe) The safety of parallel execution.
#     #   Supported values: :unsafe (default), :restricted, :safe
#     # @option [Symbol] :security (:invoker) Define the role under which the function is invoked
#     #   Supported values: :invoker (default), :definer
#     # @option [Boolean] :leakproof (false) If the function is leakproof
#     # @option [Boolean] :strict (false) If the function is strict
#     # @option [Float] :cost (nil) The cost estimation for the function
#     # @option [Integer] :rows (nil) The number of rows returned by a function
#     # @option [#to_s] :comment The description of the function
#     # @yield [f] the block with the function's definition
#     # @yieldparam Object receiver of methods specifying the function
#     # @return [void]
#     #
#     # The function can be created either using inline syntax
#     #
#     # ```ruby
#     # create_function "math.mult(a int, b int) int",
#     #                 language: :sql,
#     #                 body: "SELECT a * b",
#     #                 volatility: :immutable,
#     #                 leakproof: true,
#     #                 comment: "Multiplies 2 integers"
#     # ```
#     #
#     # or using a block:
#     #
#     # ```ruby
#     # create_function "math.mult(a int, b int) int" do |f|
#     #   f.language "sql" # (default)
#     #   f.body <<~SQL
#     #     SELECT a * b;
#     #   SQL
#     #   f.volatility :immutable # :stable, :volatile (default)
#     #   f.parallel :safe        # :restricted, :unsafe (default)
#     #   f.security :invoker     # (default), also :definer
#     #   f.leakproof true
#     #   f.strict true
#     #   f.cost 5.0
#     #   # f.rows 1 (supported for functions returning sets of rows)
#     #   f.comment "Multiplies 2 integers"
#     # SQL
#     # ```
#     #
#     # With a `replace_existing: true` option,
#     # it will be created using the `CREATE OR REPLACE` clause.
#     # In this case the migration is irreversible because we
#     # don't know if and how to restore its previous definition.
#     #
#     # ```ruby
#     # create_function "math.mult(a int, b int) int",
#     #                 body: "SELECT a * b",
#     #                 replace_existing: true
#     # ```
#     #
#     # We presume a function without arguments should have
#     # no arguments and return `void` like
#     #
#     # ```ruby
#     # # the same as "do_something() void"
#     # create_function "do_something" do |f|
#     #   # ...
#     # end
#     # ```
#     def create_function(name, **options, &block); end
#   end
module PGTrunk::Operations::Functions
  # @private
  class CreateFunction < Base
    # The definition must be either set explicitly
    # or by reading the versioned snippet.
    validate { errors.add :body, :blank if body.blank? && version.blank? }
    validates :if_exists, :force, :new_name, absence: true

    from_sql do |server_version|
      plain_function = "NOT p.proisagg AND NOT p.proiswindow"
      plain_function = "p.prokind = 'f'" if server_version >= "11"

      <<~SQL.squish
        SELECT
          p.oid,
          (
            p.pronamespace::regnamespace || '.' || p.proname || '(' || (
              regexp_replace(
                regexp_replace(
                  pg_get_function_arguments(p.oid), '^\s*IN\s+', '', 'g'
                ), '[,]\s*IN\s+', ',', 'g'
              )
            ) || ')' || (
              CASE
                WHEN p.prorettype IS NULL THEN ''
                ELSE ' ' || pg_get_function_result(p.oid)
              END
            )
          ) AS name,
          p.prosrc AS body,
          l.lanname AS language,
          (
            CASE
              WHEN p.provolatile = 'i' THEN 'immutable'
              WHEN p.provolatile = 's' THEN 'stable'
            END
          ) AS volatility,
          ( CASE WHEN p.proleakproof THEN true END ) AS leakproof,
          ( CASE WHEN p.proisstrict THEN true END ) AS strict,
          (
            CASE
              WHEN p.proparallel = 's' THEN 'safe'
              WHEN p.proparallel = 'r' THEN 'restricted'
            END
          ) AS parallel,
          ( CASE WHEN p.prosecdef THEN 'definer' END ) AS security,
          ( CASE WHEN p.procost != 100 THEN p.procost END ) AS cost,
          ( CASE WHEN p.prorows != 0 THEN p.prorows END ) AS rows,
          d.description AS comment
        FROM pg_proc p
          JOIN pg_trunk e ON e.oid = p.oid
          JOIN pg_language l ON l.oid = p.prolang
          LEFT JOIN pg_description d ON d.objoid = p.oid
        WHERE e.classid = 'pg_proc'::regclass
          AND #{plain_function};
      SQL
    end

    def to_sql(version)
      [
        create_function,
        *comment_function,
        register_function(version),
      ].join(" ")
    end

    def invert
      irreversible!("replace_existing: true") if replace_existing
      DropFunction.new(**to_h)
    end

    private

    def create_function
      sql = "CREATE"
      sql << " OR REPLACE" if replace_existing
      sql << " FUNCTION #{name.to_sql(true)}"
      sql << " RETURNS #{name.returns}" if name.returns
      sql << " RETURNS void" if name.returns.blank? && name.args.blank?
      sql << " LANGUAGE #{language || 'sql'}"
      sql << " IMMUTABLE" if volatility == :immutable
      sql << " STABLE" if volatility == :stable
      sql << " VOLATILE" if volatility.blank? || volatility == :volatile
      sql << " LEAKPROOF" if leakproof
      sql << " NOT LEAKPROOF" unless leakproof
      sql << " STRICT" if strict
      sql << " CALLED ON NULL INPUT" if strict == false
      sql << " SECURITY DEFINER" if security == :definer
      sql << " SECURITY INVOKER" if security == :invoker
      sql << " PARALLEL SAFE" if parallel == :safe
      sql << " PARALLEL RESTRICTED" if parallel == :restricted
      sql << " PARALLEL UNSAFE" if parallel.blank? || parallel == :unsafe
      sql << " COST #{cost}" if cost
      sql << " ROWS #{rows}" if rows
      sql << " AS $$#{body}$$;"
    end

    def comment_function
      <<~SQL
        COMMENT ON FUNCTION #{name.to_sql(true)}
        IS $comment$#{comment}$comment$;
      SQL
    end

    # Register the most recent `oid` of functions with this schema/name
    # There can be several overloaded definitions, but we're interested
    # in that one we created just now so we can skip checking its args.
    def register_function(version)
      function_only = "NOT proisagg AND NOT proiswindow"
      function_only = "prokind = 'f'" if version >= "11"

      <<~SQL.squish
        WITH latest AS (
          SELECT
            oid,
            (
              proname = #{name.quoted} AND pronamespace = #{name.namespace}
            ) AS ok
          FROM pg_proc
          WHERE #{function_only}
          ORDER BY oid DESC LIMIT 1
        )
        INSERT INTO pg_trunk (oid, classid)
          SELECT oid, 'pg_proc'::regclass
          FROM latest
          WHERE ok
        ON CONFLICT DO NOTHING;
      SQL
    end
  end
end
