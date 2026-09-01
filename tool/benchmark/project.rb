require "fileutils"
require "timeout"

module TypeProf
  module Benchmark
    ROOT = File.expand_path("../..", __dir__)
    TMP_DIR = File.join(ROOT, "tmp", "benchmark")
    PROJECTS_DIR = File.join(TMP_DIR, "projects")
    OUT_DIR = File.join(TMP_DIR, "out")

    # Only to catch hangs; generous so that a slow CI runner never trips it.
    TIMEOUT = 120

    class Project
      attr_reader :name

      def initialize(name:, repo:, ref:)
        @name = name
        @repo = repo
        @ref = ref
      end

      def dir = File.join(PROJECTS_DIR, @name)

      # `git clone --branch` rejects SHAs; init + fetch handles any ref (GitHub allows SHA fetches).
      def prepare!
        return if Dir.exist?(dir)

        puts "Preparing #{ @name }"
        FileUtils.mkdir_p(dir)
        git!("init", "-q")
        git!("remote", "add", "origin", @repo)
        git!("fetch", "--depth", "1", "-q", "origin", @ref)
        git!("checkout", "-q", "FETCH_HEAD")
      rescue Exception
        # A half-made clone would pass the guard above forever; let the next run retry.
        FileUtils.rm_rf(dir)
        raise
      end

      def measure
        FileUtils.mkdir_p(OUT_DIR)
        out_path = File.join(OUT_DIR, "#{ @name }.out")
        # `--no-collection` pins the bare analysis even if an rbs_collection.yaml appears in cwd.
        cmd = ["bundle", "exec", "ruby", File.join(ROOT, "bin/typeprof"),
               "-o", out_path, "--no-collection", "--show-stats", "--show-errors", dir]

        result = { name: @name }.merge(execute(cmd))
        result.merge!(parse_stats(File.read(out_path))) if result[:status] == :ok
        result
      end

      private

      def git!(*args) = system("git", "-C", dir, *args, exception: true)

      # A subprocess per project: one project's heap would otherwise skew the
      # next one's timing, and a crash is contained to that project.
      def execute(cmd)
        t = Process.clock_gettime(Process::CLOCK_MONOTONIC)

        pid = Process.spawn(*cmd)
        begin
          Timeout.timeout(TIMEOUT) { Process.waitpid(pid) }
        rescue Timeout::Error
          Process.kill("KILL", pid)
          Process.waitpid(pid)
          return { status: :timeout, error: "exceeded #{ TIMEOUT }s" }
        end

        if $?.success?
          elapsed = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - t).round(2)
          { status: :ok, elapsed: }
        else
          { status: :crash, error: "exited with #{ $?.exitstatus || "signal #{ $?.termsig }" }" }
        end
      end

      def parse_stats(text)
        m = text.match(/^# Overall:\s*(\d+)\/(\d+)/) or raise "no statistics in the output"

        {
          overall: { typed: m[1].to_i, total: m[2].to_i },
          # One line per diagnostic, e.g. "# (239,27)-(239,30):undefined method: nil#[]"
          diagnostics: text.each_line.count {|line| line.match?(/^# \(\d+,\d+\)-\(\d+,\d+\):/) },
        }
      end
    end
  end
end
