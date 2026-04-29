#!/usr/bin/env ruby

require_relative "../benchmark_helper"

TypeProf::Benchmark.run(
  name: "optcarrot",
  repo: "https://github.com/mame/optcarrot.git",
  ref: "9c88f5f752341087270b0e86e741d73f19e52369", # 2026-04-29 HEAD
)
