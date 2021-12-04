# frozen_string_literal: true

require "active_record"
require "active_record/migration"
require "pg"
require "rails/railtie"

# PGExtra adds methods to `ActiveRecord::Migration`
# to create and manage PostgreSQL objects
# in Rails applications.
module PGExtra
  require_relative "pg_extra/version"
  require_relative "pg_extra/core"
  require_relative "pg_extra/operations"
end
