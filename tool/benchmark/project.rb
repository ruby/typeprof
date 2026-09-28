require "bundler"
require "fileutils"
require "timeout"

module TypeProf
  module Benchmark
    ROOT = File.expand_path("../..", __dir__)
    TMP_DIR = File.join(ROOT, "tmp", "benchmark")
    PROJECTS_DIR = File.join(TMP_DIR, "projects")
    OUT_DIR = File.join(TMP_DIR, "out")
    # BUNDLE_PATH: outside the project dirs, where TypeProf would analyze the gems too.
    # BUNDLER_VERSION: a Gemfile.lock committed by the project would otherwise switch
    # Bundler to the version that wrote it, which may lack cooldown.
    BUNDLE_ENV = {
      "BUNDLE_PATH" => File.join(TMP_DIR, "bundle"),
      "BUNDLER_VERSION" => Bundler::VERSION,
    }.freeze

    # Written into each project's Gemfile as the current time, so that Bundler
    # resolves the same versions on every run. Cooldown counts whole days, so the
    # versions actually installed are those of the day before.
    SNAPSHOT = "Time.utc(2026, 9, 1)"
    # The last commit of ruby/gem_rbs_collection before SNAPSHOT.
    RBS_COLLECTION_REVISION = "eaf3904b06ff3325534efa989ee697b2d7686363"

    # Only to catch hangs; generous so that a slow CI runner never trips it.
    TIMEOUT = 300

    class Project
      attr_reader :name

      def initialize(name:, repo:, ref:)
        @name = name
        @repo = repo
        @ref = ref
      end

      def dir = File.join(PROJECTS_DIR, @name)

      def prepare!
        puts "Preparing #{ @name }"
        checkout!
        install_gems!
        install_rbs_collection!
      end

      # Runs in the project's bundle, which is where the RBS shipped inside a
      # gem is found. The rbs and prism versions therefore follow the project,
      # not typeprof's own Gemfile.lock.
      def measure
        FileUtils.mkdir_p(OUT_DIR)
        out_path = File.join(OUT_DIR, "#{ @name }.out")
        cmd = ["bundle", "exec", "typeprof", "-o", out_path, "--show-stats", "--show-errors", "."]

        result = { name: @name }.merge(execute(cmd))
        result.merge!(parse_stats(File.read(out_path))) if result[:status] == :ok
        result
      end

      private

      # `git clone --branch` rejects SHAs; init + fetch handles any ref (GitHub allows SHA fetches).
      # Redone on every run: a Gemfile.lock left by an earlier run would keep
      # its gem versions even after SNAPSHOT changes.
      def checkout!
        unless Dir.exist?(dir)
          FileUtils.mkdir_p(dir)
          git!("init", "-q")
          git!("remote", "add", "origin", @repo)
        end
        git!("fetch", "--depth", "1", "-q", "origin", @ref)
        git!("checkout", "-q", "--force", "FETCH_HEAD")
        git!("clean", "-q", "-f", "-d", "-x")
      end

      # Installs the gems as of SNAPSHOT, without a lockfile of our own to maintain.
      def install_gems!
        path = File.join(dir, "Gemfile")
        gemfile = File.read(path)
        # Run on the Ruby at hand, not the one the project pins.
        gemfile.sub!(/^ruby[ (].*\n/, "")
        # This project is typeprof itself; its gemspec would declare typeprof twice.
        gemfile.sub!(/^gemspec\n/, "") or raise "gemspec not found" if @name == "typeprof"
        # Pinning Bundler's "now" makes its cooldown drop everything released after
        # SNAPSHOT. Versions the project itself locked, and gems from git, are kept.
        File.write(path, gemfile + <<~RUBY)
          gem "typeprof", path: #{ ROOT.dump }, require: false
          Bundler::Resolver.private_method_defined?(:cooldown_now) or raise "Bundler::Resolver#cooldown_now is gone"
          Bundler::Resolver.prepend(Module.new { private def cooldown_now = #{ SNAPSHOT } })
        RUBY

        bundle!("install", "--quiet", "--cooldown", "1")
      end

      def install_rbs_collection!
        bundle!("exec", "rbs", "collection", "init", out: File::NULL)
        # Keeps the RBS from moving between runs: the generated config would
        # otherwise track the main branch of the collection.
        config = File.join(dir, "rbs_collection.yaml")
        yaml = File.read(config)
        yaml.sub!(/^(\s*revision:) main$/, "\\1 #{ RBS_COLLECTION_REVISION }") or raise "revision not found"
        File.write(config, yaml)
        bundle!("exec", "rbs", "collection", "install", out: File::NULL)
      end

      def git!(*args) = system("git", "-C", dir, *args, exception: true)

      def bundle!(*args, **opts)
        system(BUNDLE_ENV, "bundle", *args, chdir: dir, exception: true, **opts)
      end

      # A subprocess per project: one project's heap would otherwise skew the
      # next one's timing, and a crash is contained to that project.
      def execute(cmd)
        t = Process.clock_gettime(Process::CLOCK_MONOTONIC)

        pid = Process.spawn(BUNDLE_ENV, *cmd, chdir: dir)
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
