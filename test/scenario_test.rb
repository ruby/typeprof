require_relative "helper"
require_relative "scenario_compiler"

ScenarioCompiler.new(Dir.glob(File.join(__dir__, "../smoke/**/*.rb")), interactive: false).run