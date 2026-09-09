require_relative "../helper"
require "stringio"
require "tempfile"
require "tmpdir"

module TypeProf::Core
  class ServiceTest < Test::Unit::TestCase
    def test_runtime_error
      options = {}
      service = TypeProf::Core::Service.new(options)

      # Mocking an error while analyzing a file
      service.extend(Module.new do
        def update_rb_file(*)
          raise
        end
      end)

      Tempfile.create(["", ".rb"]) do |f|
        output = StringIO.new(+"")
        assert_raises(RuntimeError) { service.batch([f.path], output) }
        assert_equal("# error: #{f.path}\n", output.string)
      end
    end

    def test_add_workspace_reads_non_ascii_files_as_utf8
      with_non_ascii_workspace do |rb_dir, rbs_dir|
        with_default_external(Encoding::US_ASCII) do
          service = TypeProf::Core::Service.new({})
          service.add_workspace(rb_dir, rbs_dir)

          assert_match(/def bar: -> String/, service.dump_declarations(File.join(rb_dir, "foo.rb")))
        end
      end
    end

    def test_batch_reads_non_ascii_files_as_utf8
      with_non_ascii_workspace do |rb_dir, rbs_dir|
        with_default_external(Encoding::US_ASCII) do
          service = TypeProf::Core::Service.new({})
          output = StringIO.new(+"")
          files = [File.join(rbs_dir, "foo.rbs"), File.join(rb_dir, "foo.rb")]
          service.batch(files, output)
          assert_match(/def bar: -> String/, output.string)
        end
      end
    end

    private

    def with_non_ascii_workspace
      Dir.mktmpdir do |dir|
        rb_dir = File.join(dir, "lib")
        rbs_dir = File.join(dir, "sig")
        Dir.mkdir(rb_dir)
        Dir.mkdir(rbs_dir)
        File.write(File.join(rbs_dir, "foo.rbs"), "# 日本語コメント\nclass Foo\n  def bar: () -> String\nend\n", encoding: "UTF-8")
        File.write(File.join(rb_dir, "foo.rb"), "# 日本語コメント\nclass Foo\n  def bar = \"あ\"\nend\n", encoding: "UTF-8")
        yield rb_dir, rbs_dir
      end
    end
  end
end
