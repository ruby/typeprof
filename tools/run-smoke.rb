require_relative "../lib/type-profiler"

alias original_puts puts
def puts(*s)
  if $output
    s.join.split("\n").each {|l| $output << l.chomp }
  else
    original_puts(s)
  end
end
def run(f)
  $output = []
  TypeProfiler.type_profile(TypeProfiler::ISeq.compile(f))
  output = $output
  output
ensure
  $output = nil
end

files = ARGV
if ARGV.first == "--update"
  ARGV.shift
  update = true
end
files = Dir.glob("smoke/*.rb").sort if files.empty?
files.each do |f|
  begin
    exp = File.foreach(f).drop_while {|s| s.chomp != "__END__" }.drop(1).map {|s| s.chomp }
    act = run(f)
  rescue RuntimeError, StandardError, NotImplementedError
    puts "# NG: #{ f }"
    puts $!.inspect
    $!.backtrace.each {|s| puts s }
  else
    if exp == act
      puts "# OK: #{ f }"
    else
      if update
        puts "# Update!: #{ f }"
        File.write(f, File.read(f).gsub(/^__END__$.*\z/m) { "__END__\n" + act.join("\n") } + "\n")
      else
        puts "# NG: #{ f }"
        puts "expected:"
        puts exp
        puts "actual:"
        puts act
      end
    end
  end
end
