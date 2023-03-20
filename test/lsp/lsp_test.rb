require_relative "../helper"

module TypeProf::LSP
  class LSPTest < Test::Unit::TestCase
    class DummyIO
      def initialize
        @read_buffer = Thread::Queue.new
        @write_buffer = Thread::Queue.new
      end

      attr_reader :read_buffer, :write_buffer

      def read
        loop do
          yield @read_buffer.shift
        end
      end

      def write(**json)
        @write_buffer << json
      end
    end

    def setup
      @dummy_io = DummyIO.new
      @th = Thread.new do
        core = TypeProf::Core::Service.new
        serv = TypeProf::LSP::Server.new(core, @dummy_io, @dummy_io)
        serv.run
      end
      @id = 0
    end

    def init(fixture)
      @folder = "file://" + File.expand_path(File.join(__dir__, "fixtures", fixture)) + "/"
      req("initialize", workspaceFolders: [{ uri: @folder }]) do |recv|
        assert_equal({ name: "typeprof", version: TypeProf::VERSION }, recv[:serverInfo])
      end
      notify("initialized")
    end

    def teardown
      req("shutdown") do |recv|
        assert_nil(recv)
      end
      notify("exit")
      @th.join
    end

    def req(method, **params)
      @id += 1
      json = { method:, id: @id, params: }
      @dummy_io.read_buffer << json

      json = @dummy_io.write_buffer.shift
      json => { id:, result: }
      raise "unexpected id: #{ id }" if @id != id
      yield result
    end

    def notify(method, **params)
      json = { method:, params: }
      @dummy_io.read_buffer << json
    end

    def test_basic
      init("basic")

      notify(
        "textDocument/didOpen",
        textDocument: { uri: @folder + "basic.rb", version: 0, text: <<-END },
def foo(nnn)
  nnn
end

foo(1)
        END
      )

      req(
        "textDocument/hover",
        textDocument: { uri: @folder + "basic.rb" },
        position: { line: 0, character: 9 },
      ) do |json|
        assert_equal({ contents: { language: "ruby", value: "Integer" }}, json)
      end

      notify(
        "textDocument/didChange",
        textDocument: { uri: @folder + "basic.rb", version: 1 },
        contentChanges: [
          {
            range: { start: { line: 4, character: 5 }, end: { line: 4, character: 5 }},
            text: ".0", # foo(1) => foo(1.0)
          }
        ]
      )

      req(
        "textDocument/hover",
        textDocument: { uri: @folder + "basic.rb" },
        position: { line: 0, character: 9 },
      ) do |json|
        assert_equal({ contents: { language: "ruby", value: "Float" }}, json)
      end

      notify(
        "textDocument/didClose",
        textDocument: { uri: @folder + "basic.rb" },
      )
    end
  end
end