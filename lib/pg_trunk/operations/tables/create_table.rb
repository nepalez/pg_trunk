# frozen_string_literal: true

module PGTrunk::Operations::Tables
  # @private
  #
  # When dealing with tables we're only interested in
  # dumping tables one-by-one to enable other operations
  # in between tables.
  #
  # We doesn't overload the method `create_table`, but
  # keep the original implementation unchanged. That's why
  # neither `to_sql`, `invert` or `generates_object` are necessary.
  #
  # While we rely on the original implementation,
  # there are some differences in a way we fetching
  # tables and dumping them to the schema:
  #
  # - we extracting both qualified +name+ and +oid+ for every table,
  #   and checking them against the content of `pg_trunk`;
  # - we wrap every table new_name this class for dependencies resolving;
  # - we don't keep indexes and check constraints
  #   inside the table definitions because they can depend
  #   on functions which, in turn, can depend on tables.
  #
  class CreateTable < PGTrunk::Operation
    # No other attributes except for the mandatory `name` and `oid` are needed.
    # We also use default ordering by qualified names.
    validates :oid, presence: true

    # SQL to fetch table names and oids from the database.
    # We rely on the fact all tables of interest are registered in `pg_trunk`.
    from_sql do
      <<~SQL
        SELECT
          c.oid,
          (c.relnamespace::regnamespace || '.' || c.relname) AS name
        FROM pg_class c JOIN pg_trunk p ON p.oid = c.oid
        -- 'r' for tables and 'p' for partitions
        WHERE c.relkind IN ('r', 'p')
      SQL
    end

    # Instead of defining +ruby_snippet+, we overload
    # the +to_ruby+ to rely on the original implementation.
    #
    # We overloaded the +ActiveRecord::SchemaDumper+
    # methods +indexes_in_create+ and +check_constraints_in_create+
    # so that they do nothing to exclude indexes and constraints
    # from a table definition.
    #
    # @see +PGTrunk::SchemaDumper+ module (in `core/railtie`).
    def to_ruby
      stream = StringIO.new
      PGTrunk.dumper.send(:table, name.lean, stream)
      unindent(stream.string)
    end

    private

    # ActiveRecord builds the dump indented by 2 space chars.
    # Because the +to_ruby+ method is used in error messages,
    # we do indentation separately in the +PGTrunk::SchemaDumper+.
    #
    # That's why we have to unindent the original snippet
    # provided by the +ActiveRecord::Dumper##table+ method call
    # back by 2 space characters.
    #
    # The `.strip << "\n"` is added for the compatibility
    # with the +RubyBuilder+ which returns snippets
    # having one trailing newline only.
    def unindent(snippet)
      snippet.lines.map { |line| line.sub(/^ {1,2}/, "") }.join.strip << "\n"
    end
  end
end
