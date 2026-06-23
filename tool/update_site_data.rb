#!/usr/bin/env ruby
require "json"

abort "Usage: ruby update_site_data.rb data.json result1.json [result2.json...]" if ARGV.size < 2
data_path, *result_paths = ARGV

sha = ENV.fetch("GITHUB_SHA") { `git rev-parse HEAD`.strip }

data = JSON.parse(File.read(data_path))
data["repo"] = ENV.fetch("GITHUB_REPOSITORY", "ruby/typeprof")
data["entries"] << {
  "sha" => sha,
  "timestamp" => Time.now.iso8601,
  "projects" => result_paths.map { JSON.parse(File.read(_1)) },
}
data["entries"] = data["entries"].last(500)

json = JSON.pretty_generate(data)
File.write(data_path, json)
# Per-commit snapshot. The next bench run fetches its parent's snapshot
# via this unique URL (<sha>.json), avoiding stale CDN responses that a
# shared data.json URL would risk.
File.write(File.join(File.dirname(data_path), "#{sha}.json"), json)
