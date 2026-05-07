#!/usr/bin/env ruby

require "optparse"
require_relative "../lib/typeprof/version"

REPO = "ruby/typeprof"

create_branch = false
bump_kind = :patch

OptionParser.new do |opts|
  opts.banner = "Usage: ruby tool/bump.rb [--minor|--major] [-b|--branch]"
  opts.on("--minor", "Bump minor version") { bump_kind = :minor }
  opts.on("--major", "Bump major version") { bump_kind = :major }
  opts.on("-b", "--branch", "Create a new branch before committing") { create_branch = true }
end.parse!

maj, min, pat = TypeProf::VERSION.split(".").map(&:to_i)
nextver = case bump_kind
  when :patch then "#{maj}.#{min}.#{pat + 1}"
  when :minor then "#{maj}.#{min + 1}.0"
  when :major then "#{maj + 1}.0.0"
  end

branch = "master"
Dir.chdir(File.expand_path("..", __dir__)) do
  abort "must be on master" unless `git rev-parse --abbrev-ref HEAD`.strip == "master"
  abort "working tree not clean" unless `git status --porcelain`.empty?

  if create_branch
    prev_tag = `gh api repos/#{REPO}/tags --jq '.[0].name'`.strip
    abort "no previous tag found" if prev_tag.empty?
    branch = "release-from-#{prev_tag}"
    system("git switch -c #{branch}", exception: true)
  end

  version_file = "lib/typeprof/version.rb"
  File.write(version_file, File.read(version_file).sub(/VERSION = "[^"]+"/, %(VERSION = "#{nextver}")))
  system("bundle install", exception: true)
  system("git add -u", exception: true)
  system("git commit -m 'Bump version to v#{nextver}'", exception: true)
end

puts "Bumped to v#{nextver} (on #{branch})."
