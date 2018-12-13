require_relative "../lib/type-profiler"
#require "stackprof"

if ARGV[0]
  iseq = TypeProfiler::ISeq.compile(ARGV[0])
else
  iseq = TypeProfiler::ISeq.compile_str($<.read)
end
#StackProf.start(mode: :cpu, out: "stackprof.dump")
#begin
  puts TypeProfiler.type_profile(iseq)
#ensure
#  StackProf.stop
#  StackProf.results
#end
