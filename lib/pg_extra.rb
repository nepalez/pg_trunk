# frozen_string_literal: true

require "active_record"
require "active_record/connection_adapters/postgresql_adapter"
require "active_record/migration"
require "pg"
require "rails/railtie"

# @private
# PGExtra adds methods to `ActiveRecord::Migration`
# to create and manage PostgreSQL objects
# in Rails applications.
module PGExtra
  require_relative "pg_extra/version"
  require_relative "pg_extra/core"
  require_relative "pg_extra/operations"

  # @private
  def self.database
    @database ||= Adapters::Postgres.new
  end

  # @private
  def self.dumper
    @dumper ||= database.dumper
  end
end
