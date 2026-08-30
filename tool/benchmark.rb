#!/usr/bin/env ruby

# Measures TypeProf against the benchmark projects.
#
# Analyzes the working tree as it is — uncommitted changes included — writes
# the two files github-action-benchmark reads, prints a per-project summary,
# and fails if any project crashes or hangs.
#
#   $ ruby tool/benchmark.rb [project ...]
#   typeprof         ok          1.96s    79.04%  1002 diagnostics
#   ...
#   => tmp/benchmark/analysis_time.json  (customSmallerIsBetter, seconds)
#   => tmp/benchmark/type_coverage.json  (customBiggerIsBetter, typed slots %)

require "fileutils"
require "json"
require_relative "benchmark/project"

module TypeProf
  module Benchmark
    PROJECTS = [
      Project.new(
        name: "typeprof",
        repo: "https://github.com/ruby/typeprof.git",
        ref: "v0.32.0",
      ),
      Project.new(
        name: "optcarrot",
        repo: "https://github.com/mame/optcarrot.git",
        ref: "c215378a27b2dce8d8e5d98a3ed75e0354c5a840", # 2026-05-10 master
      ),
      Project.new(
        name: "rubygems.org",
        repo: "https://github.com/rubygems/rubygems.org.git",
        ref: "2abc82667d02ef7ae3a1433d621c1f7463985c6d", # 2026-08-28 master
      ),
      Project.new(
        name: "redmine",
        repo: "https://github.com/redmine/redmine.git",
        ref: "7.0.1",
      ),
    ]

    def self.run(names)
      unknown = names - PROJECTS.map(&:name)
      abort "unknown project: #{ unknown.join(", ") }" unless unknown.empty?
      projects = names.empty? ? PROJECTS : PROJECTS.select {|project| names.include?(project.name) }

      # `bundle exec` for the children resolves the Gemfile from here.
      Dir.chdir(ROOT)

      # A stale lockfile (e.g. after switching branches) would crash every project.
      system("bundle", "install", "--quiet") or raise "bundle install failed"

      analysis_time = []
      type_coverage = []
      failed = false

      projects.each do |project|
        project.prepare!
        result = project.measure

        if result[:status] == :ok
          typed, total = result[:overall].values_at(:typed, :total)
          pct = total.zero? ? 0.0 : (typed * 100.0 / total).round(2)
          puts format("%-16s %-7s %8.2fs %8.2f%% %5d diagnostics",
                      result[:name], result[:status], result[:elapsed], pct, result[:diagnostics])
          analysis_time << { name: result[:name], unit: "s", value: result[:elapsed] }
          type_coverage << { name: result[:name], unit: "%", value: pct }
        else
          failed = true
          puts format("%-16s %-7s %s", result[:name], result[:status], result[:error])
        end
      end

      FileUtils.mkdir_p(TMP_DIR)
      File.write(File.join(TMP_DIR, "analysis_time.json"), JSON.pretty_generate(analysis_time))
      File.write(File.join(TMP_DIR, "type_coverage.json"), JSON.pretty_generate(type_coverage))

      !failed
    end
  end
end

exit TypeProf::Benchmark.run(ARGV)
