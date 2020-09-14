require_relative "test_helper"
require_relative "../../lib/type-profiler"

module TypeProfiler
  class GoodcheckTest < Test::Unit::TestCase
    test "testbed/goodcheck" do
      begin
        load_path_back = $LOAD_PATH

        # ignore attached rbs
        class << RBS::EnvironmentLoader
          alias orig_gem_sig_path gem_sig_path
          remove_method :gem_sig_path
          def gem_sig_path(name, version)
            return nil if name == "goodcheck"
            orig_gem_sig_path(name, version)
          end
        end

        path = File.join(__dir__, "../../testbed/goodcheck/exe/goodcheck")
        name = "testbed/goodcheck/exe/goodcheck"

        testbed_dir = File.join(__dir__, "../../testbed/goodcheck/")
        File.write(File.join(testbed_dir, "Gemfile.lock"), File.read(File.join(testbed_dir, "../goodcheck-Gemfile.lock")))
        system("bundle", "install", "--gemfile=" + File.join(testbed_dir, "Gemfile")) || raise
        Bundler.reset!
        ENV["BUNDLE_GEMFILE"] = File.join(testbed_dir, "Gemfile")
        Bundler.setup

        actual = TestRun.run(name, File.read(path), show_errors: false, detailed_stub: false)


        # No special reason to choose these two classes (Goodcheck::Analyzer and Trigger)

        assert(actual =~ /^class Goodcheck::Analyzer\n(?:(?:  .*?\n)*)^end\n/)
        assert_equal(<<~END, $&)
          class Goodcheck::Analyzer
            attr_reader rule : untyped
            attr_reader trigger : untyped
            attr_reader buffer : Goodcheck::Buffer
            def initialize : (rule: untyped, trigger: untyped, buffer: Goodcheck::Buffer) -> Goodcheck::Buffer
            def scan : { (Goodcheck::Issue) -> Array[Goodcheck::Issue]? } -> Array[Goodcheck::Issue]?
            def scan_simple : (Regexp) { (Goodcheck::Issue) -> Array[Goodcheck::Issue]? } -> Array[Goodcheck::Issue]?
            def scan_var : (untyped) -> nil
          end
        END

        assert(actual =~ /^class Goodcheck::Trigger\n(?:(?:  .*?\n)*)^end\n/)
        assert_equal(<<~END, $&)
          class Goodcheck::Trigger
            @by_pattern : bool
            @skips_fail_examples : bool
            attr_reader patterns : Array[(Goodcheck::Pattern::Literal | Goodcheck::Pattern::Regexp | Goodcheck::Pattern::Token)?]
            attr_reader globs : Array[Goodcheck::Glob?]
            attr_reader passes : Array[Array[untyped]]
            attr_reader fails : Array[Array[untyped]]
            attr_reader negated : bool
            def initialize : (patterns: Array[(Goodcheck::Pattern::Literal | Goodcheck::Pattern::Regexp | Goodcheck::Pattern::Token)?], globs: Array[Goodcheck::Glob?], passes: Array[Array[untyped]], fails: Array[Array[untyped]], negated: bool) -> false
            def by_pattern! : -> Goodcheck::Trigger
            def by_pattern? : -> bool
            def skips_fail_examples! : (?bool) -> Goodcheck::Trigger
            def skips_fail_examples? : -> bool
            def negated? : -> bool
            def fires_for? : (path: untyped) -> bool
          end
        END

      ensure
        $LOAD_PATH.replace(load_path_back)
      end
    end
  end
end
