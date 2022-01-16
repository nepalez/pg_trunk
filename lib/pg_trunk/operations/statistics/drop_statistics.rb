# frozen_string_literal: false

# @!parse
#   class ActiveRecord::Migration
#     # Drop a custom statistics
#     #
#     # @param [#to_s] name (nil) The qualified name of the statistics
#     # @option options [Boolean] :if_exists (false) Suppress the error when the statistics is absent
#     # @option options [Symbol] :force (:restrict) How to process dependent objects (`:cascade` or `:restrict`)
#     # @option options [#to_s] table (nil)
#     #   The qualified name of the table whose statistics will be collected
#     # @option options [Array<Symbol>] kinds ([:dependencies, :mcv, :ndistinct])
#     #   The kinds of statistics to be collected (all by default).
#     #   Supported values in the array: :dependencies, :mcv, :ndistinct
#     # @option options [#to_s] :comment The description of the statistics
#     # @yield [s] the block with the statistics' definition
#     # @yieldparam Object receiver of methods specifying the statistics
#     # @return [void]
#     #
#     # A statistics can be dropped by its name only:
#     #
#     # ```ruby
#     # drop_statistics "my_stats"
#     # ```
#     #
#     # Such operation is irreversible. To make it inverted
#     # you have to provide a full definition:
#     #
#     # ```ruby
#     # drop_statistics "users_stat" do |s|
#     #   s.table "users"
#     #   s.columns "firstname", "name"
#     #   s.expression <<~SQL
#     #     round(age, 10)
#     #   SQL
#     #   s.kinds :dependency, :mcv, :ndistinct
#     #   s.comment "Statistics for name, firstname, and rough age"
#     # SQL
#     # ```
#     #
#     # If the statistics was anonymous (used the generated name),
#     # it can be dropped without defining the name as well:
#     #
#     # ```ruby
#     # drop_statistics do |s|
#     #   s.table "users"
#     #   s.columns "firstname", "name"
#     #   s.expression <<~SQL
#     #     round(age, 10)
#     #   SQL
#     #   s.kinds :dependency, :mcv, :ndistinct
#     #   s.comment "Statistics for name, firstname, and rough age"
#     # SQL
#     # ```
#     #
#     # The operation can be called with `if_exists` option. In this case
#     # it would do nothing when no statistics existed.
#     #
#     # ```ruby
#     # drop_statistics "unknown_statistics", if_exists: true
#     # ```
#     #
#     # Notice, that this option make the operation irreversible because of
#     # uncertainty about the previous state of the database.
#     def drop_statistics(name, **options, &block); end
#   end
module PGTrunk::Operations::Statistics
  # @private
  class DropStatistics < Base
    validates :if_not_exists, :new_name, absence: true

    def to_sql(_version)
      sql = "DROP STATISTICS"
      sql << " IF EXISTS" if if_exists
      sql << " #{name.to_sql}"
      sql << " CASCADE" if force == :cascade
      sql << ";"
    end

    def invert
      irreversible!("if_exists: true") if if_exists
      irreversible!("force: :cascade") if force == :cascade
      CreateStatistics.new(**to_h.except(:force))
    end
  end
end
