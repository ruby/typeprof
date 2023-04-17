class ScenarioCompiler
  def initialize(scenarios, interactive: true, fast: true)
    @scenarios = scenarios
    @interactive = interactive
    @fast = fast
  end

  def compile
    header + @scenarios.map {|scenario| compile_scenario(scenario) }.join("\n") + footer
  end

  def run
    eval(compile)
  end

  def header
    <<~END
      require #{ File.join(__dir__, "../lib/typeprof").dump }
      require #{ File.join(__dir__, "helper").dump }
      class ScenarioTest < Test::Unit::TestCase
        core = TypeProf::Core::Service.new
        _ = core # stop "unused" warning
    END
  end

  def footer
    <<~END
      end
    END
  end

  def compile_scenario(scenario)
    @file = "test.rb"
    out = %(eval(<<'TYPEPROF_SCENARIO_END', nil, #{ scenario.dump }, 1)\n)
    out << %(test(#{ scenario.dump }) {)
    unless @fast
      out << "core = TypeProf::Core::Service.new;"
    end
    close_str = ""
    File.foreach(scenario, chomp: true) do |line|
      if line =~ /\A#(?!#)\s*/
        out << close_str
        if line =~ /\A#\s*(\w+)(?::(.*))?\z/
          @file = $2.strip if $2
          ary = send("handle_#{ $1 }").lines.map {|s| s.strip }.join(";").split("DATA")
          raise if ary.size != 2
          open_str, close_str = ary
          out << open_str.chomp
          close_str += "\n"
        else
          raise "unknown directive: #{ line.inspect }"
        end
      else
        raise "NUL found" if line.include?("\0")
        out << line << "\n"
      end
    end
    out << close_str
    if @interactive
      out << <<-END
        at_exit do
          puts "---"
          puts core.dump_declarations(#{ @file.dump })
          core.diagnostics(#{ @file.dump }) {|diag| pp diag }
        end
      END
    else
      out << "core.reset!\n"
    end
    out << "}\n"
    out << %(TYPEPROF_SCENARIO_END\n)
  end

  def handle_update
    ext = File.extname(@file)[1..]
    <<-END
#{ @interactive ? 2 : 1 }.times {
  core.update_#{ ext }_file(#{ @file.dump }, %q\0DATA\0)
};
    END
  end

  def handle_assert
    <<-END
output = core.dump_declarations(#{ @file.dump })
assert_equal(%q\0DATA\0.rstrip, output.rstrip)
RBS::Parser.parse_signature(output)
    END
  end

  def handle_diagnostics
    <<-END
output = []
core.diagnostics(#{ @file.dump }) {|diag|
  output << (diag.code_range.to_s << ': ' << diag.msg)
}
output = output.join(\"\\n\")
assert_equal(%q\0DATA\0.rstrip, output)
    END
  end

  def handle_hover
    re = /\A\s*\(\s*(\d+)\s*,\s*(\d+)\s*\)\s*\n/
    <<-END
raise unless %q\0DATA\0 =~ %r{#{ re }}
output = core.hover(#{ @file.dump }, TypeProf::CodePosition.new($1.to_i, $2.to_i))
assert_equal($'.strip, output.strip)
    END
  end
end