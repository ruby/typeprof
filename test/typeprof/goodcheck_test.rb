require_relative "test_helper"
require_relative "../../lib/typeprof"
require "bundler"

module TypeProf
  class GoodcheckTest < Test::Unit::TestCase
    test "testbed/goodcheck" do
      omit_if(ENV["RUBY"], "goodcheck testbed is not supported yet in test-bundled-gems")

      begin
        TestRun.setup_testbed_repository("goodcheck", "https://github.com/sider/goodcheck.git", "b78f0f6f90887a97aa369e287fa109a63cee4a04")

        load_path_back = $LOAD_PATH
        env_bundle_gemfile_back = ENV["BUNDLE_GEMFILE"]

        # ignore attached rbs
        class << RBS::EnvironmentLoader
          alias orig_gem_sig_path gem_sig_path
          remove_method :gem_sig_path
          def gem_sig_path(name, version)
            return nil if name == "goodcheck"
            orig_gem_sig_path(name, version)
          end
        end

        Bundler.reset!
        testbed_dir = File.join(__dir__, "../../testbed/goodcheck/")
        File.write(File.join(testbed_dir, "Gemfile.lock"), File.read(File.join(testbed_dir, "../goodcheck-Gemfile.lock")))
        ENV.delete("BUNDLE_GEMFILE")
        ENV.delete("RUBYOPT")
        system("bundle", "install", "--quiet", chdir: testbed_dir) || raise("failed to bundle install in goodcheck")
        ENV["BUNDLE_GEMFILE"] = File.join(testbed_dir, "Gemfile")
        Bundler.setup

        name = "testbed/goodcheck/exe/goodcheck"
        actual = TestRun.run(name, show_errors: false, show_untyped: false, gem_rbs_features: ["pstore", "dbm"])

        # No special reason to choose these two classes (Goodcheck::Analyzer and Trigger)

        assert(actual =~ /^module Goodcheck\n.*(^  class Analyzer\n(?:(?:    .*?\n|\n)*)^  end\n).*^end\n/m)
        assert_equal(<<-END, $1)
  class Analyzer
    attr_reader rule: untyped
    attr_reader trigger: untyped
    attr_reader buffer: Buffer
    def initialize: (rule: untyped, trigger: untyped, buffer: Buffer) -> Buffer
    def scan: ?{ (Issue) -> Array[bot]? } -> ((Array[Issue] | Enumerator[Issue, untyped] | Enumerator[bot, untyped])?)
    def scan_simple: (Regexp regexp) ?{ (Issue) -> Array[bot]? } -> Array[Issue]?
    def scan_var: (untyped pat) ?{ (Issue) -> untyped } -> nil
  end
        END

        assert(actual =~ /^module Goodcheck\n.*(^  class Trigger\n(?:(?:    .*?\n|\n)*)^  end\n).*^end\n/m)
        actual = $1
        exp = TypeProf::ISeq::CASE_WHEN_CHECKMATCH ? "untyped" : "Array\\[bot\\]"
        assert_match(Regexp.compile(Regexp.quote(<<-END).gsub("HOLE", exp)), actual)
  class Trigger
    @by_pattern: bool
    @skips_fail_examples: bool

    attr_reader patterns: Array[(Pattern::Literal | Pattern::Regexp | Pattern::Token)?]
    attr_reader globs: Array[Glob?]
    attr_reader passes: Array[HOLE]
    attr_reader fails: Array[HOLE]
    attr_reader negated: bool
    def initialize: (patterns: Array[(Pattern::Literal | Pattern::Regexp | Pattern::Token)?], globs: Array[Glob?], passes: Array[HOLE], fails: Array[HOLE], negated: bool) -> false
    def by_pattern!: -> Trigger
    def by_pattern?: -> bool
    def skips_fail_examples!: (?bool flag) -> Trigger
    def skips_fail_examples?: -> bool
    def negated?: -> bool
    def fires_for?: (path: untyped) -> bool
  end
        END

      ensure
        $LOAD_PATH.replace(load_path_back)
        ENV["BUNDLE_GEMFILE"] = env_bundle_gemfile_back
      end
    end
  end
end
