#!/usr/bin/env ruby

require_relative "../benchmark_helper"

TypeProf::Benchmark.run(
  name: "typeprof",
  repo: "https://github.com/ruby/typeprof.git",
  ref: "v0.31.1",
  exclude: ["scenario/**/*"],
)
