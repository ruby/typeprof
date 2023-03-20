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
      id = request("initialize", workspaceFolders: [{ uri: @folder }])
      expect_response(id) do |recv|
        assert_equal({ name: "typeprof", version: TypeProf::VERSION }, recv[:serverInfo])
      end
      notify("initialized")
    end

    def teardown
      id = request("shutdown")
      expect_response(id) do |recv|
        assert_nil(recv)
      end
      notify("exit")
      @th.join
    end

    def notify(method, **params)
      json = { method:, params: }
      @dummy_io.read_buffer << json
    end

    def request(method, **params)
      @id += 1
      json = { method:, id: @id, params: }
      @dummy_io.read_buffer << json
      @id
    end

    def expect_response(id)
      json = @dummy_io.write_buffer.shift
      json => { id: id2, result: }
      assert_equal(id, id2, "unexpected method id (expected: #{ id }, actual: #{ id2 })")
      yield result
    end

    def expect_notification(m)
      json = @dummy_io.write_buffer.shift
      assert_nil(json[:id], "notification is expected but response is returned")
      json => { method:, params: }
      assert_equal(m, method)
      yield params
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

      expect_notification("textDocument/publishDiagnostics") do |json|
        assert_equal([], json[:diagnostics])
      end

      notify(
        "textDocument/didClose",
        textDocument: { uri: @folder + "basic.rb" },
      )
    end

    def test_hover
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

      expect_notification("textDocument/publishDiagnostics") do |json|
        assert_equal([], json[:diagnostics])
      end

      id = request(
        "textDocument/hover",
        textDocument: { uri: @folder + "basic.rb" },
        position: { line: 0, character: 9 },
      )

      expect_response(id) do |json|
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

      expect_notification("textDocument/publishDiagnostics") do |json|
        assert_equal([], json[:diagnostics])
      end

      id = request(
        "textDocument/hover",
        textDocument: { uri: @folder + "basic.rb" },
        position: { line: 0, character: 9 },
      )
      expect_response(id) do |json|
        assert_equal({ contents: { language: "ruby", value: "Float" }}, json)
      end
    end

    def test_diagnostics
      init("basic")

      notify(
        "textDocument/didOpen",
        textDocument: { uri: @folder + "basic.rb", version: 0, text: <<-END },
def foo(nnn)
  nnn
end

foo(1, 2)
        END
      )

      expect_notification("textDocument/publishDiagnostics") do |json|
        assert_equal([
          {
            message: "wrong number of arguments (2 for 1)",
            range: {
              start: { line: 4, character: 0 },
              end: { line: 4, character: 9 },
            },
            severity: 1,
            source: "TypeProf",
          }
        ], json[:diagnostics])
      end
    end

    def test_completion
      init("basic")

      notify(
        "textDocument/didOpen",
        textDocument: { uri: @folder + "basic.rb", version: 0, text: <<-END },
class Foo
  def foo(n)
    1
  end
  def bar(n)
    "str"
  end
end

def test(x)
  x.
end

Foo.new.foo(1.0)
test(Foo.new)
        END
      )

      expect_notification("textDocument/publishDiagnostics") do |json|
      end

      id = request(
        "textDocument/completion",
        textDocument: { uri: @folder + "basic.rb" },
        position: { line: 10, character: 4 },
      )
      expect_response(id) do |json|
        items = json[:items]
        assert_equal(:foo, items[0][:label])
        assert_equal("Foo#foo : (Float) -> Integer", items[0][:detail])
        assert_equal(:bar, items[1][:label])
        assert_equal("Foo#bar : (untyped) -> String", items[1][:detail])
      end
    end
  end
end