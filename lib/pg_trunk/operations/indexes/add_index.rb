# frozen_string_literal: true

module PGTrunk::Operations::Indexes
  # @private
  #
  # PGTrunk excludes indexes from table definitions provided by Rails.
  # That's why we have to fetch and dump indexes separately.
  #
  # We fetch indexes from the database by their names and oids,
  # and then rely on the original method +ActiveRecord::SchemaDumper#add_index+
  #
  # We doesn't overload the method `create_table`, but
  # keep the original implementation unchanged. That's why
  # neither `to_sql`, `invert` or `generates_object` are necessary.
  #
  class AddIndex < PGTrunk::Operation
    attribute :table, :pg_trunk_qualified_name

    validates :oid, :table, presence: true

    # Indexes are ordered by table and name
    def <=>(other)
      return unless other.is_a?(self.class)

      result = table <=> other.table
      result&.zero? ? super : result
    end

    # SQL to fetch table names and oids from the database.
    # We only extract (oid, table, name) for indexes that
    # are not used as primary key constraints.
    #
    # Primary keys are added inside tables because
    # they cannot depend on anything else.
    from_sql do
      <<~SQL
        SELECT
          c.oid,
          (c.relnamespace::regnamespace || '.' || c.relname) AS name,
          (t.relnamespace::regnamespace || '.' || t.relname) AS "table"
        FROM pg_class c
          -- ensure the table was created by a migration
          JOIN pg_trunk p ON p.oid = c.oid
          JOIN pg_index i ON i.indexrelid = c.oid
          JOIN pg_class t ON t.oid = i.indrelid
        -- ignore primary keys
        WHERE NOT i.indisprimary
      SQL
    end

    # Instead of defining +ruby_snippet+, we overload
    # the +to_ruby+ to rely on the original implementation.
    #
    # We overloaded the +ActiveRecord::SchemaDumper+
    # method +indexes_in_create+ so that it does nothing
    # to exclude indexes from a table definition.
    #
    # @see +PGTrunk::SchemaDumper+ module (in `core/railtie`).
    def to_ruby
      indexes = PGTrunk.database.send(:indexes, table.lean)
      index = indexes.find { |i| i.name == name.lean }
      return unless index

      line = PGTrunk.dumper.send(:index_parts, index).join(", ")
      "add_index #{table.lean.inspect}, #{line}"
    end
  end
end
