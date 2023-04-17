require_relative "helper"
require_relative "scenario_compiler"

slow = ENV["SLOW"]
ScenarioCompiler.new(Dir.glob(File.join(__dir__, "../scenario/**/*.rb")), interactive: false, fast: !slow).run