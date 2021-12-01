# frozen_string_literal: true

require "bundler/gem_tasks"
require "rspec/core/rake_task"

namespace :dummy do
  require_relative "spec/dummy/config/application"
  Dummy::Application.load_tasks
end

task(:spec).clear
desc "Run specs"
RSpec::Core::RakeTask.new(:spec) { |task| task.verbose = false }

desc "Run the specs on the dummy database"
task default: %w[dummy:db:reset spec]
