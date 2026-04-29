require "json"
require "bundler"

module TypeProf
  module Benchmark
    TMP_DIR = File.expand_path("../tmp", __dir__)
    TYPEPROF_ROOT = File.expand_path("..", __dir__)
    TYPEPROF_BIN = File.join(TYPEPROF_ROOT, "bin/typeprof")
    BUNDLE_EXEC_TYPEPROF = ["bundle", "exec", "typeprof"].freeze

    # coverage_per_slot:   percentage of type slots (each method's argument/return) inferred
    # coverage_per_method: percentage of methods whose all slots are inferred (fully typed)
    Result = Data.define(:name, :elapsed, :coverage_per_slot, :coverage_per_method)

    class << self
      def run(name:, repo:, ref:, targets: ["."], exclude: [], setup: nil)
        workspace = clone_if_needed(name, repo, ref)
        Dir.chdir(workspace) do
          # Run setup and typeprof in the same target-bundle context so their rbs
          # versions match. The setup must add typeprof to the target's Gemfile.
          if setup
            Bundler.with_unbundled_env do
              setup.call
              result = run_typeprof(name: name, targets: targets, exclude: exclude, command: BUNDLE_EXEC_TYPEPROF)
              write_result(name, result)
            end
          else
            result = run_typeprof(name: name, targets: targets, exclude: exclude, command: [TYPEPROF_BIN])
            write_result(name, result)
          end
        end
      end

      private

      def write_result(name, result)
        json = JSON.pretty_generate(result.to_h)
        File.write(File.join(TMP_DIR, "#{name}_result.json"), json)
        puts json
      end

      def clone_if_needed(name, repo, ref)
        dir = File.join(TMP_DIR, name)
        return dir if Dir.exist?(File.join(dir, ".git"))

        # Unified init + fetch + checkout for any ref (SHA / tag / branch).
        # `git clone --branch` is noisier (annotated tags emit a "is not a
        # commit" warning + detached HEAD advice) and doesn't accept SHAs.
        # Fetching by SHA works thanks to GitHub's uploadpack.allowAnySHA1InWant.
        system("git init -q #{dir}", exception: true)
        system("git -C #{dir} remote add origin #{repo}", exception: true)
        system("git -C #{dir} fetch --depth 1 -q origin #{ref}", exception: true)
        system("git -C #{dir} checkout -q FETCH_HEAD", exception: true)
        dir
      end

      def run_typeprof(name:, targets:, exclude:, command:)
        out_path = File.join(TMP_DIR, "#{name}_typeprof.out")
        argv = ["-o", out_path, "--show-stats", *exclude.flat_map { ["--exclude", _1] }, *targets]

        $stderr.puts "Running: #{command.join(" ")} #{argv.inspect}"
        t = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        system(*command, *argv, exception: true)
        elapsed = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - t).round(2)

        Result.new(name: name, elapsed: elapsed, **parse_and_compute(out_path))
      end

      def parse_and_compute(out_path)
        # `--show-stats` appends the statistics block at the end of the same
        # -o output file (after the RBS dump). Locate that block and parse it.
        text = File.read(out_path)
        idx = text.rindex("# TypeProf Evaluation Statistics") or raise "stats block not found in #{out_path}"
        block = text[idx..]

        methods = block[/Total methods:\s*(\d+)/, 1].to_i
        fully_typed = block[/Fully typed:\s*(\d+)/, 1].to_i
        overall_typed, overall_total = block.match(/Overall:\s*(\d+)\/(\d+)/).captures.map(&:to_i)

        {
          coverage_per_slot: (overall_typed * 100.0 / overall_total).round(2),
          coverage_per_method: (fully_typed * 100.0 / methods).round(2),
        }
      end
    end
  end
end
