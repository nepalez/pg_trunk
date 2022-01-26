# frozen_string_literal: false

# @!parse
#   class ActiveRecord::Migration
#     # Modify a sequence
#     #
#     # @param [#to_s] name (nil) The qualified name of the sequence.
#     # @option options [Boolean] :if_exists (false) Suppress the error when the sequence is absent.
#     # @yield [s] the block with the sequence's definition.
#     # @yieldparam Object receiver of methods specifying the sequence.
#     # @return [void]
#     #
#     # The operation enables to alter a sequence without recreating it.
#     # PostgreSQL allows any setting to be modified. The comment can be
#     # changed as well.
#     #
#     # ```ruby
#     # change_sequence "my_schema.global_id" do |s|
#     #   s.owned_by "", "", from: %w[users gid]
#     #   s.type "smallint", from: "integer"
#     #   s.iterate_by 1, from: 2
#     #   s.min_value 1, from: 0
#     #   s.max_value 2000, from: 1999
#     #   s.start_with 2, from: 1
#     #   s.cache 1, from: 10
#     #   s.cycle false
#     #   s.comment "Identifier", from: "Global identifier"
#     # end
#     # ```
#     #
#     # As in the snippet above, to make the change invertible,
#     # you have to define from option for every changed attribute,
#     # except for the boolean `cycle`.
#     #
#     # With the `if_exists: true` option, the operation won't raise
#     # when the sequence is absent.
#     #
#     # ```ruby
#     # change_sequence "my_schema.global_id", if_exists: true do |s|
#     #   s.type "smallint"
#     #   s.iterate_by 1
#     #   s.min_value 1
#     #   s.max_value 2000
#     #   s.start_with 2
#     #   s.cache 1
#     #   s.cycle false
#     #   s.comment "Identifier"
#     # end
#     # ```
#     #
#     # This option makes a migration irreversible due to uncertainty
#     # of the previous state of the database. That's why in the last
#     # example no `from:` option was added (they are useless).
#     def change_sequence(name, **options, &block); end
#   end
module PGTrunk::Operations::Sequences
  # @private
  class ChangeSequence < Base
    # Operation-specific validations
    validate { errors.add :base, "Changes can't be blank" if changes.blank? }
    validates :force, :if_not_exists, :new_name, absence: true

    def owned_by(table, column, from: nil)
      self.table = table
      self.column = column
      self.from_table, self.from_column = Array(from)
    end

    def to_sql(_version)
      [*alter_sequence, *update_comment].join(" ")
    end

    def invert
      irreversible!("if_exists: true") if if_exists
      undefined = inversion.select { |_, v| v.nil? }.keys.join(", ").presence
      raise IrreversibleMigration.new(self, nil, <<~MSG.squish) if undefined
        Undefined values to revert #{undefined}.
      MSG

      self.class.new(name: name, **inversion) if inversion.any?
    end

    private

    INF = (2**63) - 1

    def changes
      @changes ||= attributes.symbolize_keys.except(:name, :if_exists).compact
    end

    def inversion
      @inversion ||= changes.each_with_object({}) do |(key, val), obj|
        obj[key] = send(:"from_#{key}")
        obj[key] = !val if [true, false].include?(val)
      end
    end

    def alter_sequence
      return if changes.except(:comment).blank?

      sql = "ALTER SEQUENCE"
      sql << " IF EXISTS" if if_exists
      sql << " #{name.to_sql}"
      sql << " AS #{type}" if type.present?
      sql << " INCREMENT BY #{increment_by}" if increment_by.present?
      sql << " MINVALUE #{min_value}" if min_value&.>(-INF)
      sql << " NO MINVALUE" if min_value&.<=(-INF)
      sql << " MAXVALUE #{max_value}" if max_value&.<(INF)
      sql << " NO MAXVALUE" if max_value&.>=(INF)
      sql << " START WITH #{start_with}" if start_with.present?
      sql << " CACHE #{cache}" if cache.present?
      sql << " OWNED BY #{table}.#{column}" if table.present? && column.present?
      sql << " OWNED BY NONE" if table == "" || column == ""
      sql << " CYCLE" if cycle
      sql << " NO CYCLE" if cycle == false
      sql << ";"
    end

    def update_comment
      return unless comment
      return <<~SQL.squish unless if_exists
        COMMENT ON SEQUENCE #{name.to_sql} IS $comment$#{comment}$comment$;
      SQL

      # change the comment conditionally
      <<~SQL.squish
        DO $$
          BEGIN
            IF EXISTS (
              SELECT FROM pg_sequence s JOIN pg_class c ON c.oid = s.seqrelid
              WHERE c.relname = #{name.quoted}
                AND c.relnamespace = #{name.namespace}
            ) THEN
              COMMENT ON SEQUENCE #{name.to_sql}
                IS $comment$#{comment}$comment$;
            END IF;
          END
        $$;
      SQL
    end
  end
end
