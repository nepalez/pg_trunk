# frozen_string_literal: false

# @!method ActiveRecord::Migration#change_domain(name, &block)
# Modify a domain type
#
# @param [#to_s] name (nil) The qualified name of the type
# @yield [Proc] the block with the type's definition
# @yieldparam The receiver of methods specifying the type
#
# The operation can be used to add or remove constraints,
# modify the default_sql value, or the description of the domain type.
# Neither the underlying type nor the collation can be changed.
#
#   change_domain "dict.us_postal_code" do |d|
#     d.null true # from: false
#     # check is added for inversion
#     d.drop_constraint "postal_code_length", check: <<~SQL
#       length(VALUE) > 3 AND length(VALUE) < 6
#     SQL
#     d.add_constraint <<~SQL, name: "postal_code_valid"
#       VALUE ~ '^\d{5}$' OR VALUE ~ '^\d{5}-\d{4}$'
#     SQL
#     d.default_sql "'00000'::text", from: "'0000'::text"
#     d.comment <<~COMMENT, from: <<~COMMENT
#       Supported currencies
#     COMMENT
#       Currencies
#     COMMENT
#   end
#
# Use blank string (not a `nil` value) to reset either a default_sql,
# or the comment. `nil`-s here will be ignored.
#
# When dropping a constraint you can use a `check` expression.
# In the same manner, use `from` option with `comment` or `default_sql`
# to make the operation invertible.
#
# It is irreversible in case any `drop_constraint` clause
# has `if_exists: true` or `force: :cascade` option -- due to
# uncertainty of the previous state of the database:
#
#   # Irreversible change
#   change_domain "dict.us_postal_code", force: :cascade do |d|
#     d.drop_constraint "postal_code_valid" # missed `:check` option
#     d.drop_constraint "postal_code_length"
#     d.drop_constraint "postal_code_format", if_exists: true
#     d.default_sql "'0000'::text" # missed `:from` option
#     d.comment "New comment" # missed `:from` option
#   end

module PGExtra::Operations::Domains
  # @private
  class ChangeDomain < Base
    # Methods to populate `constraints` from the block

    def add_constraint(check, name: nil, valid: true)
      constraints << Constraint.new(name: name, check: check, valid: valid)
    end

    def rename_constraint(name, to:)
      constraints << Constraint.new(name: name, new_name: to)
    end

    def validate_constraint(name)
      constraints << Constraint.new(name: name, valid: true)
    end

    def drop_constraint(name, check: nil, if_exists: nil)
      constraints << Constraint.new(
        check: check,
        drop: true,
        force: force,
        if_exists: if_exists,
        name: name,
      )
    end

    validates :if_exists, :new_name, :type, :collation, absence: true
    validate { errors.add :base, "There are no changes" if change.blank? }

    def to_sql(_version)
      [*change_default, *change_null, *change_constraints, *change_comment]
        .join(" ")
    end

    def invert
      keys = inversion.select { |_, v| v.nil? }.keys.join(", ").presence
      errors = constraints.map(&:inversion_error).compact
      errors << "Can't invert #{keys}" if keys.present?
      raise IrreversibleMigration.new(self, nil, *errors) if errors.any?

      self.class.new(**to_h, **inversion)
    end

    private

    def change_default
      <<~SQL.squish if default_sql
        ALTER DOMAIN #{name.to_sql}
        #{default_sql.present? ? "SET DEFAULT #{default_sql}" : 'DROP DEFAULT'};
      SQL
    end

    def change_null
      <<~SQL.squish unless null.nil?
        ALTER DOMAIN #{name.to_sql} #{null ? 'DROP' : 'SET'} NOT NULL;
      SQL
    end

    def change_constraints
      constraints.map do |c|
        "ALTER DOMAIN #{name.to_sql} #{c.to_sql};"
      end
    end

    def change_comment
      <<~SQL.squish if comment
        COMMENT ON DOMAIN #{name.to_sql} IS $comment$#{comment}$comment$;
      SQL
    end

    def change
      @change ||= {
        comment: comment,
        constraints: constraints.map(&:to_h).presence,
        default_sql: default_sql,
        null: null,
      }.compact
    end

    def inversion
      @inversion ||= {
        comment: from_comment,
        constraints: constraints&.map(&:invert),
        default_sql: from_default_sql,
        null: !null,
      }.slice(*change.keys)
    end
  end
end
