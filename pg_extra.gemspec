# frozen_string_literal: true

lib = File.expand_path("lib", __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "pg_extra/version"

Gem::Specification.new do |spec|
  spec.name = "pg_extra"
  spec.version = PGExtra::VERSION
  spec.authors = ["Andrew Kozin"]
  spec.email = ["andrew.kozin@gmail.com"]

  spec.summary = "Empower PostgreSQL migrations in Rails app"
  spec.description = <<-DESCRIPTION
    Adds methods to ActiveRecord::Migration to create and manage PostgreSQL objects in Rails
  DESCRIPTION
  spec.homepage = "https://github.com/nepalez/pg_extra"
  spec.license = "MIT"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = `git ls-files -z`.split("\x0")
  spec.test_files = spec.files.grep(%r{^spec/})
  spec.require_paths = ["lib"]

  spec.add_dependency "activerecord", ">= 4.0.0"
  spec.add_dependency "pg"
  spec.add_dependency "railties", ">= 4.0.0"

  spec.required_ruby_version = ">= 2.5.0"
end
