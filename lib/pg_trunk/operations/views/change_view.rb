# frozen_string_literal: false

# @!method ActiveRecord::Migration#change_view(name, **options, &block)
# Modify a view
#
# @param [#to_s] name (nil) The qualified name of the view
# @option [Boolean] :if_exists (false) Suppress the error when the view is absent
# @yield [Proc] the block with the view's definition
# @yieldparam The receiver of methods specifying the view
#
# The operation replaces the view with a new definition(s):
#
#   change_view "admin_users" do |v|
#     v.sql_definition: <<~SQL, from: <<~SQL
#       SELECT id, name FROM users WHERE admin;
#     SQL
#       SELECT * FROM users WHERE admin;
#     SQL
#   end
#
# For some compatibility to the `scenic` gem, we also support
# adding a definition via its version:
#
#    change_view "admin_users" do |v|
#      v.version 2, from: 1
#    end
#
# It is expected, that both `db/views/admin_users_v01.sql`
# and `db/views/admin_users_v02.sql` to contain SQL snippets.
#
# Please, notice that neither deletion of columns,
# nor changing their types is supported by the PostgreSQL.
#
# You can also (re)set a comment describing the view,
# and the check option (either `:local` or `:cascaded`):
#
#   change_view "admin_users" do |v|
#     v.check :local, from: :cascaded
#     v.comment "Admin users only", from: ""
#   end

module PGTrunk::Operations::Views
  # @private
  class ChangeView < Base
    validates :replace_existing, :force, :new_name, absence: true
    validate { errors.add :base, "Changes can't be blank" if changes.blank? }
    validate do
      next if if_exists || name.blank?

      errors.add :base, "Can't find the view #{name.lean}" unless create_view
    end

    def to_sql(server_version)
      create_view&.to_sql(server_version)
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

    def changes
      @changes ||= to_h.slice(:sql_definition, :check, :comment).compact
    end

    def inversion
      @inversion ||= {}.tap do |inv|
        inv[:version] = from_version if version
        inv[:sql_definition] = from_sql_definition unless version
        inv[:check] = from_check if check
        inv[:comment] = from_comment if comment
      end
    end

    def create_view
      return if name.blank?

      @create_view ||= CreateView.find { |o| o.name == name }&.tap do |op|
        op.attributes = { **changes, replace_existing: true }
      end
    end
  end
end
