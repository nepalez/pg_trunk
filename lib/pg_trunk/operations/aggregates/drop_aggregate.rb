# frozen_string_literal: false

module PGTrunk::Operations::Aggregates
  #
  # Definition for the `drop_aggregate` operation
  #
  # An aggregate can be dropped by a plain name:
  #
  #   drop_aggregate "multiply"
  #
  # If several aggregates share the same name,
  # then you must specify the signature:
  #
  #   drop_aggregate "multiply(int, int)"
  #
  # In both cases above the operation is irreversible. To make it
  # inverted, provide a full signature along with the body definition.
  # The other options are supported as well:
  #
  #   drop_aggregate "math.mult(a int, b int) int" do |f|
  #     f.language "sql" # (default)
  #     f.body <<~SQL
  #       SELECT a * b;
  #     SQL
  #     f.comment "Multiplies 2 integers"
  #   end
  #
  # The operation can be called with `if_exists` option. In this case
  # it would do nothing when no aggregate existed.
  #
  #   drop_aggregate "math.multiply(integer, integer)", if_exists: true
  #
  # Another operation-specific option `force: :cascade` enables
  # to drop silently any object depending on the aggregate.
  #
  #   drop_aggregate "math.multiply(integer, integer)", force: :cascade
  #
  # Both options make the operation irreversible because of
  # uncertainty about the previous state of the database.
  #
  class DropAggregate < Base
    validates :into, absence: true
    validates :replace_existing, absence: true

    def to_sql(_version)
      sql = "DROP AGGREGATE"
      sql << " IF EXISTS" if if_exists
      sql << " #{name.to_sql}"
      sql << " CASCADE" if force == :cascade
      sql << ";"
    end

    def invert
      irreversible!("if_exists: true") if if_exists
      irreversible!("force: :cascade") if force == :cascade
      CreateAggregate.new(**to_h.except(:force))
    end
  end
end
