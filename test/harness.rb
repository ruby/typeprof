require_relative "../lib/typeprof"

module TypeProf::Core
  def self.test_harness(smoke, interactive)
    core = Service.new
    file = "test.rb"
    File.read(smoke).scan(/^#(?!#)(.*)\n((?:.|\n)*?)(?=^#|\z)/) do |cmd, code|
      code = code.gsub(/\s+\z/, "")
      case cmd.strip
      when /^update(?::(.*))?$/
        file = $1.strip if $1
        core.update_file(file, code)
        core.update_file(file, code) unless interactive
      when /^assert(?::(.*))?$/
        file = $1.strip if $1
        actual = core.dump_declarations(file).chomp
        if interactive
          raise "unmatch\nexpected: %p\nactual:   %p" % [code, actual] if code != actual
        else
          yield code, actual
        end
        RBS::Parser.parse_signature(actual)
      when /^diagnostics(?::(.*))?$/
        actual = []
        core.diagnostics(file) do |diag|
          actual << "#{ diag.code_range.to_s }: #{ diag.msg }"
        end
        actual = actual.join("\n")
        if interactive
          raise "unmatch\nexpected: %p\nactual:   %p" % [code, actual] if code != actual
        else
          yield code, actual
        end
      when /^hover: *\( *(\d+), *(\d+) *\)$/
        row, col = $1.to_i, $2.to_i
        pos = TypeProf::CodePosition.new(row, col)
        actual = core.hover(file, pos)
        if interactive
          raise "unmatch\nexpected: %p\nactual:   %p" % [code, actual] if code != actual
        else
          yield code, actual
        end
      else
        raise "unknown directive: #{ cmd.strip.inspect }"
      end
    end
    if interactive
      puts core.dump_declarations(file)
      #core.dump_graph(file)
      core.diagnostics(file) do |diag|
        pp diag
      end
    end
  end
end

if $0 == __FILE__
  TypeProf::Core.test_harness(ARGV[0], true)
end
