require_relative "../lib/type-profiler"

files = ARGV
files = Dir.glob("smoke/*.rb").sort if files.empty?
files.each do |f|
  begin
    exp = File.foreach(f).drop_while {|s| s.chomp != "__END__" }.drop(1).map {|s| s.chomp }
    act = TypeProfiler.type_profile(TypeProfiler::ISeq.compile(f))
  rescue RuntimeError, NotImplementedError
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
