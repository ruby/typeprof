require_relative "../lib/typeprof"
require "stackprof"
#require "pf2"
include TypeProf::Core

core = Service.new
#Pf2.start([Thread.current], false)

StackProf.run(out: "stackprof/stackprof.dump", raw: true) do
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
  #p ObjectSpace.each_object(TypeProf::Core::Site).to_a.size

  h = Hash.new(0)
  core.genv.type_table.each {|(t,*),| h[t] += 1 }
  pp h
end

#File.write("typeprof2.pf2profile", Pf2.stop)
