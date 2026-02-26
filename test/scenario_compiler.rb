class ScenarioCompiler
  def initialize(scenarios, output_declarations: false, check_diff: true, fast: true)
    @scenarios = scenarios
    @output_declarations = output_declarations
    @check_diff = check_diff
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
        core = TypeProf::Core::Service.new({})
        _ = core # stop "unused" warning
    END
  end

  def footer
    <<~END
      end
    END
  end

  def scan_markers(line, markers, file, line_count, scenario)
    pos = 0
    while md = line.match(/(\^+)\[(\w+)\]/, pos)
      carets = md[1]
      name = md[2]
      raise "duplicate marker: [#{name}] in #{scenario}" if markers[name]
      col_start = md.begin(1)
      col_end = col_start + carets.length
      markers[name] = {
        file: file,
        line: line_count,
        col_start: col_start,
        col_end: col_end,
        point: carets.length == 1,
      }
      pos = md.end(0)
    end
  end

  def resolve_marker_for_directive(markers, marker_name)
    marker = markers[marker_name]
    raise "undefined marker: [#{marker_name}]" unless marker
    @file = marker[:file]
    @pos = [marker[:line], marker[:col_start]]
  end

  def substitute_markers_in_output(line, markers)
    line.gsub(/\[(\w+)\]/) do
      name = $1
      marker = markers[name]
      if marker
        if marker[:point]
          "(#{marker[:line]},#{marker[:col_start]})"
        else
          "(#{marker[:line]},#{marker[:col_start]})-(#{marker[:line]},#{marker[:col_end]})"
        end
      else
        $&
      end
    end
  end

  def compile_scenario(scenario)
    markers = {}
    marker_file = "test.rb"
    content_line_count = 0
    @file = "test.rb"
    @pos = [0, 0]
    out = %(eval(<<'TYPEPROF_SCENARIO_END', nil, #{ scenario.dump }, 1)\n)
    out << %(test(#{ scenario.dump }) do )
    unless @fast
      out << "core = TypeProf::Core::Service.new({});"
    end
    close_str = ""
    need_comment_removal = false
    current_command = nil
    marker_continuation = false
    File.foreach(scenario, chomp: true, encoding: "UTF-8") do |line|
      if marker_continuation
        marker_continuation = false
        scan_markers(line, markers, marker_file, content_line_count, scenario)
        next
      end
      if line =~ /\A##\s*/
        out << close_str
        content_line_count = 0
        if line =~ /\A##\s*(\w+)(?::\s*(?:\[(\w+)\]|(.*?)(?::(\d+)(?::(\d+))?)?))?\z/
          current_command = $1
          if $2
            resolve_marker_for_directive(markers, $2)
          elsif $3
            marker_file = $3
            @file = $3
            @pos = [$4.to_i, $5.to_i]
          end
          ary = send("handle_#{ current_command }").lines.map {|s| s.strip }.join(";").split("DATA")
          raise if ary.size != 2
          open_str, close_str = ary
          out << open_str.chomp
          close_str += "\n"
          need_comment_removal = true if current_command == "definition"
        else
          raise "unknown directive: #{ line.inspect }"
        end
      elsif line =~ /\A#\\\s*\z/
        marker_continuation = true
      elsif line =~ /\A#[\s\^]*(?:\^+\[\w+\][\s\^]*)+\z/
        scan_markers(line, markers, marker_file, content_line_count, scenario)
      else
        content_line_count += 1
        raise "NUL found" if line.include?("\0")
        if need_comment_removal
          line = line.gsub(/#\s*.*\Z/, "")
          need_comment_removal = false
        end
        if current_command && !%w[update assert assert_without_validation].include?(current_command) && !markers.empty?
          line = substitute_markers_in_output(line, markers)
        end
        out << line.gsub("\\") { "\\\\" } << "\n"
      end
    end
    out << close_str
    if @output_declarations
      out << <<-END
        at_exit do
          puts "---"
          puts core.dump_declarations(#{ @file.dump })
          core.diagnostics(#{ @file.dump }) {|diag| pp diag }
        end
      END
    else
      out << "ensure core.reset!\n"
    end
    out << "end\n"
    out << %(TYPEPROF_SCENARIO_END\n)
  end

  def handle_update
    ext = File.extname(@file)[1..]
    <<-END
#{ @check_diff ? 2 : 1 }.times {|i|
  core.update_#{ ext }_file(#{ @file.dump }, %q\0DATA\0)
  if i != 0 && "#{ ext }" == "rb"
    if !core.instance_variable_get(:@rb_text_nodes)[#{ @file.dump }].prev_node
      raise "AST diff does not work well; the completely same code generates a different AST"
    end
  end
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

  def handle_assert_without_validation
    <<-END
output = core.dump_declarations(#{ @file.dump })
assert_equal(%q\0DATA\0.rstrip, output.rstrip)
    END
  end

  def handle_diagnostics
    <<-END
output = []
core.diagnostics(#{ @file.dump }) {|diag|
  output << [diag.code_range, diag.msg]
}
output = output.sort.map {|cr, msg| cr.to_s + ": " + msg }.join(\"\\n\")
assert_equal(%q\0DATA\0.rstrip, output)
    END
  end

  def handle_hover
    <<-END
output = core.hover(#{ @file.dump }, TypeProf::CodePosition.new(#{ @pos.join(",") }))
assert_equal(%q\0DATA\0.strip, output.strip)
    END
  end

  def handle_code_lens
    <<-END
output = []
core.code_lens(#{ @file.dump }) {|cr, hint| output << (cr.first.to_s + ": " + hint) }
output = output.join(\"\\n\")
assert_equal(%q\0DATA\0.rstrip, output)
    END
  end

  def handle_completion
    <<-END
output = []
core.completion(#{ @file.dump }, ".", TypeProf::CodePosition.new(#{ @pos.join(",") })) {|_mid, hint| output << hint }
assert_equal(exp = %q\0DATA\0.rstrip, output[0..exp.count(\"\\n\")].join(\"\\n\"))
    END
  end

  def handle_definition
    <<-END
output = core.definitions(#{ @file.dump }, TypeProf::CodePosition.new(#{ @pos.join(",") }))
assert_equal(exp = %q\0DATA\0.rstrip, output.map {|file, cr| (file || "(nil)") + ":" + cr.to_s }.join(\"\\n\"))
    END
  end

  def handle_type_definition
    <<-END
output = core.type_definitions(#{ @file.dump }, TypeProf::CodePosition.new(#{ @pos.join(",") }))
assert_equal(exp = %q\0DATA\0.rstrip, output.map {|file, cr| (file || "(nil)") + ":" + cr.to_s }.join(\"\\n\"))
    END
  end

  def handle_references
    <<-END
output = core.references(#{ @file.dump }, TypeProf::CodePosition.new(#{ @pos.join(",") }))
assert_equal(exp = %q\0DATA\0.rstrip, output.map {|file, cr| file + ":" + cr.to_s }.join(\"\\n\"))
    END
  end

  def handle_rename
    <<-END
output = core.rename(#{ @file.dump }, TypeProf::CodePosition.new(#{ @pos.join(",") }))
assert_equal(exp = %q\0DATA\0.rstrip, output.map {|file, cr| file + ":" + cr.to_s }.join(\"\\n\"))
    END
  end
end
