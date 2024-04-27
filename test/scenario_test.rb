require_relative "helper"
require_relative "scenario_compiler"

slow = ENV["SLOW"]
base_dir = File.join(File.dirname(__dir__))
scenarios = Dir.glob(File.join(base_dir, "scenario/**/*.rb"))
scenarios = scenarios.reject {|path| path.start_with?(File.join(base_dir, "scenario/known-issues")) }
scenarios = scenarios.map {|scenario| scenario.delete_prefix(base_dir + File::Separator) }
ScenarioCompiler.new(scenarios, interactive: false, fast: !slow).run
