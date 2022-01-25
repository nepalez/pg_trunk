# frozen_string_literal: false

# @!parse
#   class ActiveRecord::Migration
#     # Drop a sequence
#     #
#     # @param [#to_s] name (nil) The qualified name of the sequence
#     # @option options [#to_s] :as ("bigint") The type of the sequence's value
#     #   Supported values: "bigint" (or "int8", default), "integer" (or "int4"), "smallint" ("int2").
#     # @option options [Boolean] :if_exists (false) Suppress the error when the sequence is absent.
#     # @option options [Symbol] :force (:restrict) Define how to process dependent objects
#     #   Supported values: :restrict (default), :cascade.
#     # @option options [Integer] :increment_by (1) Non-zero step of the sequence (either positive or negative).
#     # @option options [Integer] :min_value (nil) Minimum value of the sequence.
#     # @option options [Integer] :max_value (nil) Maximum value of the sequence.
#     # @option options [Integer] :start_with (nil) The first value of the sequence.
#     # @option options [Integer] :cache (1) The number of values to be generated and cached.
#     # @option options [Boolean] :cycle (false) If the sequence should be reset to start
#     #   after its value reaches min/max value.
#     # @option options [#to_s] :comment (nil) The comment describing the sequence.
#     # @yield [s] the block with the sequence's definition
#     # @yieldparam Object receiver of methods specifying the sequence
#     # @return [void]
#     #
#     # The sequence can be dropped by its qualified name only
#     #
#     # ```ruby
#     # drop_sequence "global_number"
#     # ```
#     #
#     # For inversion provide options for the `create_sequence` operation as well:
#     #
#     # ```ruby
#     # drop_sequence "global_id", as: "int2" do |s|
#     #   s.iterate_by 2
#     #   s.min_value 0
#     #   s.max_value 1999
#     #   s.start_with 1
#     #   s.cache 10
#     #   s.cycle true
#     #   s.comment "Global identifier"
#     # end
#     # ```
#     #
#     # The operation can be called with `if_exists` option to suppress
#     # the exception in case when the sequence is absent:
#     #
#     # ```ruby
#     # drop_sequence "global_number", if_exists: true
#     # ```
#     #
#     # With the `force: :cascade` option the operation would remove
#     # all the objects that use the sequence.
#     #
#     # ```ruby
#     # drop_sequence "global_number", force: :cascade
#     # ```
#     #
#     # In both cases the operation becomes irreversible due to
#     # uncertainty of the previous state of the database.
#     def drop_sequence(name, **options, &block); end
#   end
module PGTrunk::Operations::Sequences
  # @private
  class DropSequence < Base
    validates :if_not_exists, :new_name, absence: true

    def to_sql(_version)
      sql = "DROP SEQUENCE"
      sql << " IF EXISTS" if if_exists
      sql << " #{name.to_sql}"
      sql << " CASCADE" if force == :cascade
      sql << ";"
    end

    def invert
      irreversible!("if_exists: true") if if_exists
      irreversible!("force: :cascade") if force == :cascade
      CreateSequence.new(**to_h.except(:if_exists, :force))
    end
  end
end
