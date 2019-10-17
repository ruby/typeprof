require_relative "../lib/type-profiler"

alias original_puts puts
def puts(*s)
  if $output
    s.each {|l| $output << l.chomp }
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
files = Dir.glob("smoke/*.rb").sort if files.empty?
files.each do |f|
  begin
    exp = File.foreach(f).drop_while {|s| s.chomp != "__END__" }.drop(1).map {|s| s.chomp }
    act = run(f)
  rescue RuntimeError, StandardError
    puts "# NG: #{ f }"
    puts $!.inspect
    $!.backtrace.each {|s| puts s }
  else
    if exp == act
      puts "# OK: #{ f }"
    else
      puts "# NG: #{ f }"
      puts "expected:"
      puts exp
      puts "actual:"
      puts act
    end
  end
end
