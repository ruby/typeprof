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
      @lsp = TypeProf::LSP::Server.new({}, @dummy_io, @dummy_io)
      @th = Thread.new { @lsp.run }
      @id = 0
    end

    def init(fixture, position_encodings: nil, expected_position_encoding: "utf-16")
      @folder = @lsp.path_to_uri(File.expand_path(File.join(__dir__, "..", "fixtures", fixture))) + "/"
      params = { workspaceFolders: [{ uri: @folder }] }
      params[:capabilities] = { general: { positionEncodings: position_encodings } } if position_encodings
      id = request("initialize", **params)
      expect_response(id) do |recv|
        assert_equal({ name: "typeprof", version: TypeProf::VERSION }, recv[:serverInfo])
        assert_equal(expected_position_encoding, recv[:capabilities][:positionEncoding])
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

    def expect_request(m)
      json = @dummy_io.write_buffer.shift
      json => { method:, id: _, params: }
      assert_equal(m, method)
      yield params
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

      expect_notification("typeprof.enableToggleButton") {|json| }
      expect_request("workspace/codeLens/refresh") {|json| }

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

      expect_notification("typeprof.enableToggleButton") {|json| }
      expect_request("workspace/codeLens/refresh") {|json| }

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

      expect_request("workspace/codeLens/refresh") {|json| }

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

      expect_notification("typeprof.enableToggleButton") {|json| }
      expect_request("workspace/codeLens/refresh") {|json| }
      expect_notification("textDocument/publishDiagnostics") do |json|
        assert_equal({
          uri: @folder + "basic.rb",
          diagnostics: [
            {
              message: "wrong number of arguments (2 for 1)",
              range: {
                start: { line: 4, character: 0 },
                end: { line: 4, character: 3 },
              },
              severity: 1,
              source: "TypeProf",
            }
          ],
        }, json)
      end
    end

    def test_diagnostics_ignore_directive
      init("basic")

      notify(
        "textDocument/didOpen",
        textDocument: { uri: @folder + "basic.rb", version: 0, text: <<-END },
def foo(nnn)
  nnn
end

foo(1, 2)
foo(1, 2) # typeprof:ignore
foo(1, 2)
        END
      )

      expect_notification("typeprof.enableToggleButton") {|json| }
      expect_request("workspace/codeLens/refresh") {|json| }
      expect_notification("textDocument/publishDiagnostics") do |json|
        assert_equal({
          uri: @folder + "basic.rb",
          diagnostics: [
            {
              message: "wrong number of arguments (2 for 1)",
              range: {
                start: { line: 4, character: 0 },
                end: { line: 4, character: 3 },
              },
              severity: 1,
              source: "TypeProf",
            },
            {
              message: "wrong number of arguments (2 for 1)",
              range: {
                start: { line: 6, character: 0 },
                end: { line: 6, character: 3 },
              },
              severity: 1,
              source: "TypeProf",
            }
          ],
        }, json)
      end
    end

    def test_diagnostics_ignore_directive_block
      init("basic")

      notify(
        "textDocument/didOpen",
        textDocument: { uri: @folder + "basic.rb", version: 0, text: <<-END },
def foo(nnn)
  nnn
end

# typeprof:ignore:start
foo(1, 2)
foo(1, 2)
# typeprof:ignore:end
foo(1, 2)
        END
      )

      expect_notification("typeprof.enableToggleButton") {|json| }
      expect_request("workspace/codeLens/refresh") {|json| }
      expect_notification("textDocument/publishDiagnostics") do |json|
        assert_equal({
          uri: @folder + "basic.rb",
          diagnostics: [
            {
              message: "wrong number of arguments (2 for 1)",
              range: {
                start: { line: 8, character: 0 },
                end: { line: 8, character: 3 },
              },
              severity: 1,
              source: "TypeProf",
            }
          ],
        }, json)
      end
    end

    def test_diagnostics2
      init("basic")

      notify(
        "textDocument/didOpen",
        textDocument: { uri: @folder + "basic1.rb", version: 0, text: <<-END },
def check(nnn)
  nnn
end
        END
      )
      expect_notification("typeprof.enableToggleButton") {|json| }
      expect_request("workspace/codeLens/refresh") {|json| }

      notify(
        "textDocument/didOpen",
        textDocument: { uri: @folder + "basic2.rb", version: 0, text: <<-END },
check(1, 2)
        END
      )

      expect_notification("typeprof.enableToggleButton") {|json| }
      expect_request("workspace/codeLens/refresh") {|json| }
      expect_notification("textDocument/publishDiagnostics") do |json|
        assert_equal({
          uri: @folder + "basic2.rb",
          diagnostics: [
            {
              message: "wrong number of arguments (2 for 1)",
              range: {
                start: { line: 0, character: 0 },
                end: { line: 0, character: 5 },
              },
              severity: 1,
              source: "TypeProf",
            },
          ],
        }, json)
      end

      notify(
        "textDocument/didChange",
        textDocument: { uri: @folder + "basic1.rb", version: 1 },
        contentChanges: [
          {
            range: { start: { line: 0, character: 13 }, end: { line: 0, character: 13 }},
            text: ", mmm", # def check(nnn) => def check(nnn, mmm)
          }
        ]
      )

      expect_request("workspace/codeLens/refresh") {|json| }
      expect_notification("textDocument/publishDiagnostics") do |json|
        assert_equal({ uri: @folder + "basic2.rb", diagnostics: [] }, json)
      end
    end

    def test_completion_const_csv_inserts_require
      init("basic")

      notify(
        "textDocument/didOpen",
        textDocument: { uri: @folder + "basic.rb", version: 0, text: <<~END },
          # frozen_string_literal: true

          CS
        END
      )

      expect_notification("typeprof.enableToggleButton") {|json| }
      expect_request("workspace/codeLens/refresh") {|json| }

      id = request(
        "textDocument/completion",
        textDocument: { uri: @folder + "basic.rb" },
        position: { line: 2, character: 2 },
      )
      expect_response(id) do |json|
        items = json[:items]
        csv_item = items.find { |i| i[:label] == "CSV" }
        assert_not_nil(csv_item, "CSV candidate expected")
        assert_equal(21, csv_item[:kind])
        assert_equal("from 'csv'", csv_item[:detail])
        edits = csv_item[:additionalTextEdits]
        assert_not_nil(edits)
        assert_equal(1, edits.size)
        assert_match(/require 'csv'/, edits[0][:newText])
        assert_equal(1, edits[0][:range][:start][:line])
        assert_equal(0, edits[0][:range][:start][:character])
      end
    end

    def test_completion_const_skips_require_when_already_present
      init("basic")

      notify(
        "textDocument/didOpen",
        textDocument: { uri: @folder + "basic.rb", version: 0, text: <<~END },
          require 'csv'

          CS
        END
      )

      expect_notification("typeprof.enableToggleButton") {|json| }
      expect_request("workspace/codeLens/refresh") {|json| }

      id = request(
        "textDocument/completion",
        textDocument: { uri: @folder + "basic.rb" },
        position: { line: 2, character: 2 },
      )
      expect_response(id) do |json|
        items = json[:items]
        csv_item = items.find { |i| i[:label] == "CSV" }
        assert_not_nil(csv_item)
        assert_nil(csv_item[:additionalTextEdits], "additionalTextEdits should not be set when require is already in the file")
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

      expect_notification("typeprof.enableToggleButton") {|json| }
      expect_request("workspace/codeLens/refresh") {|json| }

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

    def test_type_definition_for_class_constant
      init("type_definition")

      notify(
        "textDocument/didOpen",
        textDocument: { uri: @folder + "test.rb", version: 0, text: <<-END },
class Foo
end

foo = Foo.new
foo
        END
      )

      expect_notification("typeprof.enableToggleButton") {|json| }
      expect_request("workspace/codeLens/refresh") {|json| }

      id = request(
        "textDocument/typeDefinition",
        textDocument: { uri: @folder + "test.rb" },
        position: { line: 3, character: 6 },
      )

      expect_response(id) do |json|
        assert_equal(2, json.size)

        rbs_result = json.find { |r| r[:uri].end_with?(".rbs") }
        rb_result = json.find { |r| r[:uri].end_with?(".rb") }

        assert_not_nil(rbs_result, "RBS definition should be found")
        assert_not_nil(rb_result, "Ruby definition should be found")

        assert(rbs_result[:uri].end_with?("sig/test.rbs"))
        assert(rb_result[:uri].end_with?("test.rb"))
      end
    end

    def test_position_encoding_default
      init("basic")
      assert_equal(Encoding::UTF_16LE, @lsp.position_encoding)
    end

    def test_position_encoding_utf8_preferred
      init("basic", position_encodings: ["utf-8", "utf-16"], expected_position_encoding: "utf-8")
      assert_equal(Encoding::UTF_8, @lsp.position_encoding)
    end

    def test_position_encoding_empty_array
      init("basic", position_encodings: [], expected_position_encoding: "utf-16")
      assert_equal(Encoding::UTF_16LE, @lsp.position_encoding)
    end

    def test_position_encoding_unsupported_only
      init("basic", position_encodings: ["ascii"], expected_position_encoding: "utf-16")
      assert_equal(Encoding::UTF_16LE, @lsp.position_encoding)
    end

    def test_position_encoding_prefers_first_supported
      init("basic", position_encodings: ["ascii", "utf-16", "utf-8"], expected_position_encoding: "utf-16")
      assert_equal(Encoding::UTF_16LE, @lsp.position_encoding)
    end

    def test_position_encoding_utf32_preferred
      init("basic", position_encodings: ["utf-32", "utf-16"], expected_position_encoding: "utf-32")
      assert_equal(Encoding::UTF_32LE, @lsp.position_encoding)
    end

    def test_type_definition_for_local_variable
      init("type_definition")

      notify(
        "textDocument/didOpen",
        textDocument: { uri: @folder + "test.rb", version: 0, text: <<-END },
class Foo
end

foo = Foo.new
foo
        END
      )

      expect_notification("typeprof.enableToggleButton") {|json| }
      expect_request("workspace/codeLens/refresh") {|json| }

      id = request(
        "textDocument/typeDefinition",
        textDocument: { uri: @folder + "test.rb" },
        position: { line: 4, character: 0 },
      )

      expect_response(id) do |json|
        assert_equal(2, json.size)

        rbs_result = json.find { |r| r[:uri].end_with?(".rbs") }
        rb_result = json.find { |r| r[:uri].end_with?(".rb") }

        assert_not_nil(rbs_result, "RBS definition should be found")
        assert_not_nil(rb_result, "Ruby definition should be found")

        assert(rbs_result[:uri].end_with?("sig/test.rbs"))
        assert(rb_result[:uri].end_with?("test.rb"))
      end
    end
  end
end
