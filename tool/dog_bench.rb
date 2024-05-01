require_relative "../lib/typeprof"
include TypeProf::Core

def main(core)
  t = Time.now
  core.genv.run_count = 0
  Dir.glob("lib/typeprof/**/*.rb", sort: true) do |path|
    next if path.start_with?("lib/typeprof/lsp")
    puts path
    core.update_rb_file(path, File.read(path))
  end
  puts "Elapsed: #{ Time.now - t }"
  #GC.start
  #p ObjectSpace.each_object(TypeProf::Core::BasicVertex).to_a.size
  #p ObjectSpace.each_object(TypeProf::Core::Box).to_a.size

  h = Hash.new(0)
  core.genv.type_table.each {|(t,*),| h[t] += 1 }
  pp h
end

core = Service.new
if ARGV[0] == "pf2"
  require "pf2"
  Pf2.start(interval_ms: 1, time_mode: :wall, threads: [Thread.current])
  main(core)
  File.write("dog_bench.pf2profile", Pf2.stop)
else
  require "stackprof"
  StackProf.run(mode: :cpu, out: "dog_bench.stackprof.dump", raw: true) do
    main(core)
  end
end
