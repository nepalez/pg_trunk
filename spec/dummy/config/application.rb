# frozen_string_literal: true

require File.expand_path("boot", __dir__)

# Pick the frameworks you want:
require "active_record/railtie"

# noinspection RubyResolve
Bundler.require(*Rails.groups)

module Dummy
  # noinspection RubyResolve
  class Application < Rails::Application
    config.cache_classes = true
    config.eager_load = false
    config.active_support.deprecation = :stderr
  end
end
