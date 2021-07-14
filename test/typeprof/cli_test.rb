require_relative "test_helper"
require_relative "../../lib/typeprof"

module TypeProf
  class CLITest < Test::Unit::TestCase
    test "analyze multiple rb files" do
      rb_file = File.join(__dir__, "../../smoke/simple.rb")
      rb_files = [rb_file, rb_file]
      rbs_files = []
      output = StringIO.new("")
      options = {}
      options[:show_untyped] = true
      options[:show_errors] = true
      options[:show_indicator] = false
      options[:show_typeprof_version] = false
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
  def foo: (Integer n) -> String
end
      END
    end

    test "exclude untyped results" do
      rb_file = File.join(__dir__, "../../smoke/any1.rb")
      rb_files = [rb_file]
      rbs_files = []
      output = StringIO.new("")
      options = {}
      options[:exclude_untyped] = true
      options[:show_untyped] = true
      options[:show_indicator] = false
      options[:show_typeprof_version] = false
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
# def foo: -> untyped
end
      END
    end

    test "analyze with incomplete rbs file" do
      rb_file = File.join(__dir__, "../../smoke/simple.rb")
      rb_files = [rb_file]
      rbs_files = [["test.rbs", "class Bar < Foo\nend"]]
      output = StringIO.new("")
      options = {}
      options[:show_untyped] = true
      options[:show_errors] = true
      options[:show_indicator] = false
      options[:show_typeprof_version] = false
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
# Analysis Error
A constant `Foo' is used but not defined in RBS
      END
    end
  end
end
