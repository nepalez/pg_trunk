# frozen_string_literal: true

require "active_record"
require "active_record/connection_adapters/postgresql_adapter"
require "active_record/migration"
require "pg"
require "rails/railtie"

# @private
# PGTrunk adds methods to `ActiveRecord::Migration`
# to create and manage PostgreSQL objects
# in Rails applications.
module PGTrunk
  require_relative "pg_trunk/version"
  require_relative "pg_trunk/core"
  require_relative "pg_trunk/operations"

  # @private
  def self.database
    @database ||= Adapters::Postgres.new
  end

  # @private
  def self.dumper
    @dumper ||= database.dumper
  end
end
