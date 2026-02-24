require_relative "helper"
require "stringio"

module TypeProf
  class CLITest < Test::Unit::TestCase
    def test_run(fixture_path, argv)
      output = StringIO.new(+"")
      Dir.chdir(File.join(__dir__, "fixtures", fixture_path)) do
        yield if block_given?
        cli = TypeProf::CLI::CLI.new(argv)
        cli.cli_options[:output] = output
        cli.core_options[:display_indicator] = false
        cli.run
      end
      output.string
    end

    def test_e2e_basic
      assert_equal(<<~END, test_run("basic", ["."]))
        # TypeProf #{ TypeProf::VERSION }

        # ./basic.rb
        class Object
          def foo: (String) -> String
        end
      END
    end

    def test_e2e_type_error
      assert_equal(<<~END, test_run("type_error", ["."]))
        # TypeProf #{ TypeProf::VERSION }

        # ./type_error.rb
        class Object
          def check: -> :ok
        end
      END

      assert_equal(<<~END, test_run("type_error", ["--show-error", "."]))
        # TypeProf #{ TypeProf::VERSION }

        # ./type_error.rb
        # (2,10)-(2,20):wrong type of arguments
        class Object
          def check: -> :ok
        end
      END
    end

    def test_e2e_syntax_error
      assert_equal(<<~END, test_run("syntax_error", ["."]))
        # TypeProf #{ TypeProf::VERSION }

        # failed to analyze: ./syntax_error.rb
        # failed to analyze: ./syntax_error.rbs
      END
    end

    def test_e2e_no_version
      assert_equal(<<~END, test_run("basic", ["--no-show-typeprof-version", "."]))
        # ./basic.rb
        class Object
          def foo: (String) -> String
        end
      END
    end

    def test_e2e_output_param_names
      assert_equal(<<~END, test_run("basic", ["--show-parameter-names", "."]))
        # TypeProf #{ TypeProf::VERSION }

        # ./basic.rb
        class Object
          def foo: (String n) -> String
        end
      END
    end

    def test_e2e_output_source_location
      assert_equal(<<~END, test_run("basic", ["--show-source-location", "."]))
        # TypeProf #{ TypeProf::VERSION }

        # ./basic.rb
        class Object
          # ./basic.rb:1:1
          def foo: (String) -> String
        end
      END
    end

    def test_e2e_rbs_collection
      # The "rbs collection install" command attempts to create a symlink,
      # which requires elevated privileges on Windows
      omit if RUBY_PLATFORM =~ /mswin|mingw/

      exp = <<~END
        # TypeProf #{ TypeProf::VERSION }

        # test.rb
        class Object
          def check: -> :ok
        end
      END

      assert_equal(exp, test_run("rbs_collection_test", ["test.rb"]) do
        lock_path = RBS::Collection::Config.to_lockfile_path(Pathname("rbs_collection.yaml").expand_path)

        open(IO::NULL, "w") do |null_stdout|
          RBS::Collection::Installer.new(lockfile_path: lock_path, stdout: null_stdout).install_from_lockfile
        end
      end)
    end

    def test_e2e_exclude
      assert_equal(<<~END, test_run("exclude_test", ["--exclude", "**/templates/**", "."]))
        # TypeProf #{ TypeProf::VERSION }

        # ./lib/main.rb
        class Object
          def foo: (String) -> String
        end
      END
    end

    def test_e2e_show_stats
      result = test_run("show_stats", ["--no-show-typeprof-version", "--show-stats", "."])
      stats = result[/# TypeProf Evaluation Statistics.*/m]
      assert(stats, "--show-stats should output statistics section")

      # Method summary: 6 methods total
      #   initialize (no slots) → fully typed
      #   typed_method (param typed, ret typed) → fully typed
      #   with_typed_block (ret typed, block_param typed, block_ret typed) → fully typed
      #   untyped_params (2 params untyped, ret typed) → partially typed
      #   with_untyped_block (ret untyped, block_param untyped, block_ret untyped) → fully untyped
      #   uncalled_writer (param untyped, ret untyped) → fully untyped
      assert_include(stats, "# Total methods: 6")
      assert_include(stats, "#   Fully typed:     3")
      assert_include(stats, "#   Partially typed: 1")
      assert_include(stats, "#   Fully untyped:   2")

      # Parameter slots: typed_method(1 typed) + untyped_params(2 untyped) + uncalled_writer(1 untyped)
      assert_include(stats, "# Parameter slots: 4\n#   Typed:   1 (25.0%)\n#   Untyped: 3 (75.0%)")

      # Return slots: typed_method(typed) + untyped_params(typed nil) + with_typed_block(typed)
      #               + with_untyped_block(untyped) + uncalled_writer(untyped)
      assert_include(stats, "# Return slots: 5\n#   Typed:   3 (60.0%)\n#   Untyped: 2 (40.0%)")

      # Block parameter slots: with_typed_block(1 typed) + with_untyped_block(1 untyped)
      assert_include(stats, "# Block parameter slots: 2\n#   Typed:   1 (50.0%)\n#   Untyped: 1 (50.0%)")

      # Block return slots: with_typed_block(1 typed) + with_untyped_block(1 untyped)
      assert_include(stats, "# Block return slots: 2\n#   Typed:   1 (50.0%)\n#   Untyped: 1 (50.0%)")

      # Constants: TYPED_CONST(typed) + Foo::UNTYPED_CONST(untyped)
      assert_include(stats, "# Constants: 2\n#   Typed:   1 (50.0%)\n#   Untyped: 1 (50.0%)")

      # Instance variables: @typed_ivar(typed) + @untyped_ivar(untyped)
      assert_include(stats, "# Instance variables: 2\n#   Typed:   1 (50.0%)\n#   Untyped: 1 (50.0%)")

      # Class variables: @@typed_cvar(typed) + @@untyped_cvar(untyped)
      assert_include(stats, "# Class variables: 2\n#   Typed:   1 (50.0%)\n#   Untyped: 1 (50.0%)")

      # Global variables: $typed_gvar(typed) + $untyped_gvar(untyped)
      assert_include(stats, "# Global variables: 2\n#   Typed:   1 (50.0%)\n#   Untyped: 1 (50.0%)")

      # Overall: 10 typed out of 21
      assert_include(stats, "# Overall: 10/21 typed (47.6%)")
      assert_include(stats, "#          11/21 untyped (52.4%)")
    end

    def test_e2e_no_show_stats
      result = test_run("basic", ["--no-show-typeprof-version", "."])
      assert_not_include(result, "TypeProf Evaluation Statistics")
    end

    def test_lsp_options_with_lsp_mode
      assert_nothing_raised { TypeProf::CLI::CLI.new(["--lsp", "--stdio"]) }
    end

    def test_lsp_options_with_non_lsp_mode
      invalid_options = [
        ["--stdio", "."],
        ["--port", "123456", "."],
      ]

      invalid_options.each do |argv|
        stdout, _stderr = capture_output do
          assert_raises(SystemExit) { TypeProf::CLI::CLI.new(argv) }
        end
        assert_equal("invalid option: lsp options with non-lsp mode\n", stdout)
      end
    end
  end
end
