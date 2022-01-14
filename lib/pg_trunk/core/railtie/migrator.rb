# frozen_string_literal: true

module PGTrunk
  # @private
  # This module extends the ActiveRecord::Migrator
  # to clean the gem-specific registry `pg_trunk`:
  #
  # - set version to rows added by the current migration
  # - delete rows that refer to objects deleted by the migration
  #
  # We need this because some objects (like check constraints,
  # indexes etc.) can be dropped along with the table
  # they refer to. This depencency is implicit-ish.
  # That's why we have to check the presence of all objects in `pg_trunk`
  # after every single migration.
  module Migrator
    def record_version_state_after_migrating(*)
      super
      PGTrunk::Registry.finalize
    end
  end
end
