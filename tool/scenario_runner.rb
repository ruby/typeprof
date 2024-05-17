#!/usr/bin/env ruby

require "bundler/setup"

require_relative "../test/scenario_compiler"

ScenarioCompiler.new(ARGV[0] ? ARGV : ["t.rb"], output_declarations: true, check_diff: false).run
