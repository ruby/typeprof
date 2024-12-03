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
          def check: -> untyped
        end
      END

      assert_equal(<<~END, test_run("type_error", ["--show-error", "."]))
        # TypeProf #{ TypeProf::VERSION }

        # ./type_error.rb
        # (2,10)-(2,20):failed to resolve overloads
        class Object
          def check: -> untyped
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

        RBS::Collection::Installer.new(lockfile_path: lock_path).install_from_lockfile
      end)
    end
  end
end
