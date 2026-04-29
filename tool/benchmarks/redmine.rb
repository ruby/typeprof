#!/usr/bin/env ruby

require_relative "../benchmark_helper"

# Redmine 6.1.1's Gemfile pins `ruby '>= 3.2.0', '< 3.5.0'`, so `bundle add` /
# `rbs collection install` in setup fail on unsupported Ruby versions.
required_ruby = Gem::Requirement.new(">= 3.2.0", "< 3.5.0")
unless required_ruby.satisfied_by?(Gem::Version.new(RUBY_VERSION))
  warn "Skipping redmine benchmark: Redmine 6.1.1 requires Ruby #{required_ruby} (current: #{RUBY_VERSION})"
  exit 0
end

TypeProf::Benchmark.run(
  name: "redmine",
  repo: "https://github.com/redmine/redmine.git",
  ref: "6.1.1",
  targets: ["app", "sig"],
  setup: -> {
    # Each step is guarded with `unless ...` for idempotency: CI starts from a
    # fresh clone, but local re-runs reuse tmp/redmine and skip done steps.
    unless File.exist?("config/database.yml")
      File.write("config/database.yml", <<~YAML)
        development:
          adapter: sqlite3
          database: db/development.sqlite3
      YAML
    end
    gemfile = File.read("Gemfile")
    system("bundle add typeprof --path #{TypeProf::Benchmark::TYPEPROF_ROOT}", exception: true) unless gemfile.include?("typeprof")
    system("bundle add rbs_rails -v '0.13.1'", exception: true) unless gemfile.include?("rbs_rails")
    system("bin/rails db:migrate", exception: true) unless File.exist?("db/schema.rb")
    system("bundle exec rbs collection init", exception: true) unless File.exist?("rbs_collection.yaml")
    system("bundle exec rbs collection install", exception: true) unless File.exist?("rbs_collection.lock.yaml")
    system("bundle exec rbs_rails all", exception: true) unless Dir.exist?("sig/rbs_rails")
  },
)
