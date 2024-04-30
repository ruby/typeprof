require_relative "../test/scenario_compiler"

ScenarioCompiler.new(ARGV[0] ? ARGV : ["t.rb"], interactive: false).run
