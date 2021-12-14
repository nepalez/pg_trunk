# frozen_string_literal: false

# @!method ActiveRecord::Migration#change_procedure(name, **options, &block)
# Modify a procedure
#
# @param [#to_s] name (nil) The qualified name of the procedure
# @option [Boolean] :if_exists (false) Suppress the error when the procedure is absent
# @yield [Proc] the block with the procedure's definition
# @yieldparam The receiver of methods specifying the procedure
#
# The operation changes the procedure without dropping it
# (which is useful when there are other objects
# using the function and you don't want to change them all).
#
# You can change any property except for the name
# (use `rename_function` instead) and `language`.
#
#   change_procedure "metadata.set_foo(a int)" do |p|
#     p.body <<~SQL
#       SET foo = a
#     SQL
#     p.security :invoker
#     p.comment "Multiplies 2 integers"
#   SQL
#
# The example above is not invertible because of uncertainty
# about the previous state of body and comment.
# To define them, use a from options (available in a block syntax only):
#
#   change_procedure "metadata.set_foo(a int)" do |p|
#     p.body <<~SQL, from: <<~SQL
#       SET foo = a
#     SQL
#       SET foo = -a
#     SQL
#     p.comment <<~MSG, from: <<~MSG
#       Multiplies 2 integers
#     MSG
#       Multiplies ints
#     MSG
#     p.security :invoker
#   SQL
#
# Like in the other operations, the procedure can be
# identified by a qualified name (with types of arguments).
# If it has no overloaded implementations,
# the plain name is supported as well.

module PGExtra::Operations::Procedures
  # @private
  class ChangeProcedure < Base
    validates :replace_existing, :language, :new_name, absence: true
    validate { errors.add :base, "Changes can't be blank" if changes.blank? }
    validate do
      next if if_exists || name.blank? || create_procedure.present?

      errors.add :base, "Procedure #{name.lean} can't be found"
    end

    def to_sql(version)
      check_version!(version)

      # Use `CREATE OR REPLACE FUNCTION` to make changes
      create_procedure&.to_sql(version)
    end

    def invert
      irreversible!("if_exists: true") if if_exists
      undefined = inversion.select { |_, v| v.nil? }.keys.join(", ").presence
      raise IrreversibleMigration.new(self, nil, <<~MSG.squish) if undefined
        Undefined values to revert #{undefined}.
      MSG

      self.class.new(**inversion, name: name)
    end

    private

    def create_procedure
      return if name.blank?

      @create_procedure ||= begin
        list = CreateProcedure.select { |obj| name.maybe_eq?(obj.name) }
        list.select! { |obj| name == obj.name } if list.size > 1 && name.args
        list.first&.tap do |op|
          op.attributes = { **changes, replace_existing: true }
        end
      end
    end

    def changes
      @changes ||= {
        body: body.presence,
        comment: comment,
        security: security,
      }.compact
    end

    def inversion
      @inversion ||= {
        body: [body, from_body],
        comment: [comment, from_comment],
        security: [security, (%i[invoker definer] - [security]).first],
      }.slice(*changes.keys).transform_values(&:last)
    end
  end
end
