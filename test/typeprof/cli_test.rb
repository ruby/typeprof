require_relative "test_helper"
require_relative "../../lib/typeprof"

module TypeProf
  class CLITest < Test::Unit::TestCase
    test "multiple rb files" do
      rb_file = File.join(__dir__, "../../smoke/simple.rb")
      rb_files = [rb_file, rb_file]
      rbs_files = []
      output = StringIO.new("")
      options = {}
      options[:show_untyped] = true unless options.key?(:show_untyped)
      options[:show_errors] = true unless options.key?(:show_errors)
      options[:show_indicator] = false unless options.key?(:show_indicator)
      config = TypeProf::ConfigData.new(
        rb_files: rb_files,
        rbs_files: rbs_files,
        output: output,
        options: options,
        verbose: 0,
      )
      TypeProf.analyze(config)

      output = output.string

      RBS::Parser.parse_signature(output[/# Classes.*\z/m]) unless options[:skip_parsing_test]

      assert_equal(<<-END, output)
# Classes
class Object
  private
  def foo: (Integer) -> String
         | (Integer) -> String
end
      END
    end
  end
end
