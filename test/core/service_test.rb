require_relative "../helper"
require "stringio"
require "tempfile"

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
  end
end
