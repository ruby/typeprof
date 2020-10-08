#!/usr/bin/env ruby

require "stackprof"
StackProf.start(mode: :cpu, out: "stackprof-cpu.dump", raw: true, interval: 1000)
begin
  load File.join(__dir__, "../exe/typeprof")
ensure
  StackProf.stop
  StackProf.results
end
