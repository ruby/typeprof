require "socket"
require "json"
require "uri"

module TypeProf
  def self.start_lsp_server(config)
    Socket.tcp_server_sockets("localhost", config.lsp_options[:port]) do |servs|
      serv = servs[0].local_address
      $stdout << JSON.generate({
        host: serv.ip_address,
        port: serv.ip_port,
        pid: $$,
      })
      $stdout.flush

      $stdout = $stderr

      Socket.accept_loop(servs) do |sock|
        begin
          TypeProf::LSP::Server.new(config, sock).run
        ensure
          sock.close
        end
        exit
      end
    end
  end

  module LSP
    class Text
      def initialize(server, uri, text, version)
        @server = server
        @uri = uri
        @text = text
        @version = version
      end

      attr_reader :text, :version
      attr_accessor :definition_table

      def lines
        @text.lines
      end

      def apply_changes(changes, version)
        @definition_table = nil
        text = @text.empty? ? [] : @text.lines
        changes.each do |change|
          case change
          in {
            range: {
                start: { line: start_row, character: start_col },
                end:   { line: end_row  , character: end_col   }
            },
            text: change_text,
          }
          else
            raise
          end
          text << "" if start_row == text.size
          text << "" if end_row == text.size
          if start_row == end_row
            text[start_row][start_col...end_col] = change_text
          else
            text[start_row][start_col..] = ""
            text[end_row][...end_col] = ""
            change_text = change_text.lines
            case change_text.size
            when 0
              text[start_row] += text[end_row]
              text[start_row + 1 .. end_row] = []
            when 1
              text[start_row] += change_text.first + text[end_row]
              text[start_row + 1 .. end_row] = []
            else
              text[start_row] += change_text.shift
              text[end_row].prepend(change_text.pop)
              text[start_row + 1 ... end_row - 1] = change_text
            end
          end
        end
        @text = text.join
        @version = version

        @server.on_text_changed(@uri, version)
      end
    end

    class Message
      def initialize(server, json)
        @server = server
        @id = json[:id]
        @method = json[:method]
        @params = json[:params]
      end

      def run
        p [:ignored, @method]
      end

      def respond(result)
        raise "do not respond to notification" if @id == nil
        @server.send_response(id: @id, result: result)
      end

      Classes = []
      def self.inherited(klass)
        Classes << klass
      end

      Table = Hash.new(Message)
      def self.build_table
        Classes.each {|klass| Table[klass::METHOD] = klass }
      end

      def self.find(method)
        Table[method]
      end
    end

    class Message::Initialize < Message
      METHOD = "initialize"
      def run
        respond(
          capabilities: {
            textDocumentSync: {
              openClose: true,
              change: 2, # Incremental
            },
            #codeActionProvider: {
            #  codeActionKinds: ["quickfix", "refactor"],
            #  resolveProvider: false,
            #},
            codeLensProvider: {
              resolveProvider: true,
            },
            #executeCommandProvider: {
            #  commands: ["jump_to_rbs"],
            #},
            definitionProvider: true,
            typeDefinitionProvider: true,
          },
          serverInfo: {
            name: "typeprof",
            version: "0.0.0",
          },
        )
      end
    end

    class Message::Initialized < Message
      METHOD = "initialized"
      def run
      end
    end

    class Message::Shutdown < Message
      METHOD = "shutdown"
      def run
        respond(nil)
      end
    end

    module Message::Workspace
    end

    class Message::Workspace::DidChangeWatchedFiles < Message
      METHOD = "workspace/didChangeWatchedFiles"
      def run
        #p "workspace/didChangeWatchedFiles"
        #pp @params
      end
    end

    module Message::TextDocument
    end

    class Message::TextDocument::DidOpen < Message
      METHOD = "textDocument/didOpen"
      def run
        case @params
        in { textDocument: { uri:, version:, text: } }
        else
          raise
        end
        @server.open_texts[uri] = Text.new(@server, uri, text, version)
        @server.on_text_changed(uri, version)
      end
    end

    class Message::TextDocument::DidChange < Message
      METHOD = "textDocument/didChange"
      def run
        case @params
        in { textDocument: { uri:, version: }, contentChanges: changes }
        else
          raise
        end
        @server.open_texts[uri].apply_changes(changes, version)
      end
    end

    class Message::TextDocument::DidClose < Message
      METHOD = "textDocument/didClose"
      def run
        case @params
          in { textDocument: { uri: } }
        else
          raise
        end
        @server.open_texts.delete(uri)
      end
    end

    class Message::TextDocument::Definition < Message
      METHOD = "textDocument/definition"
      def run
        case @params
        in {
          textDocument: { uri:, },
          position: loc,
        }
        else
          raise
        end

        definition_table = @server.open_texts[uri].definition_table
        code_locations = definition_table[CodeLocation.from_lsp(loc)] if definition_table
        if code_locations
          respond(
            code_locations.map do |path, code_range|
              {
                uri: "file://" + path,
                range: code_range.to_lsp,
              }
            end
          )
        else
          respond(nil)
        end
      end
    end

    class Message::TextDocument::TypeDefinition < Message
      METHOD = "textDocument/typeDefinition"
      def run
        respond(nil)
        # jump example
        #respond(
        #  uri: "file:///path/to/typeprof/vscode/sandbox/test.rbs",
        #  range: {
        #    start: { line: 1, character: 4 },
        #    end: { line: 1, character: 7 },
        #  },
        #)
      end
    end

    class Message::TextDocument::CodeLens < Message
      METHOD = "textDocument/codeLens"
      def run
        respond(@server.sigs[@params[:textDocument][:uri]] || [])
      end
    end

    Message.build_table

    class Reader
      class ProtocolError < StandardError
      end

      def initialize(io)
        @io = io
      end

      def read
        while line = @io.gets
          line2 = @io.gets
          if line =~ /\AContent-length: (\d+)\r\n\z/i && line2 == "\r\n"
            len = $1.to_i
            json = JSON.parse(@io.read(len), symbolize_names: true)
            yield json
          else
            raise ProtocolError, "LSP broken header"
          end
        end
      end
    end

    class Writer
      def initialize(io)
        @io = io
      end

      def write(**json)
        json = JSON.generate(json.merge(jsonrpc: "2.0"))
        @io << "Content-Length: #{ json.size }\r\n\r\n" << json
      end

      module ErrorCodes
        ParseError = -32700
        InvalidRequest = -32600
        MethodNotFound = -32601
        InvalidParams = -32602
        InternalError = -32603
      end
    end

    module Helpers
      def pos(line, character)
        { line: line, character: character }
      end

      def range(s, e)
        { start: s, end: e }
      end
    end

    class Server
      class Exit < StandardError; end

      include Helpers

      def initialize(config, read_io, write_io = read_io)
        @config = config
        @reader = Reader.new(read_io)
        @writer = Writer.new(write_io)
        @request_id = 0
        @current_requests = {}
        @open_texts = {}
        @sigs = {} # tmp
      end

      attr_reader :open_texts, :sigs

      def run
        @reader.read do |json|
          if json[:method]
            # request or notification
            Message.find(json[:method]).new(self, json).run
          else
            callback = @current_requests.delete(json[:id])
            callback&.call(json[:params])
          end
        end
      rescue Exit
      end

      def send_response(**msg)
        @writer.write(**msg)
      end

      def send_notification(method, params = nil)
        @writer.write(method: method, params: params)
      end

      def send_request(method, params = nil, &blk)
        id = @request_id += 1
        @current_requests[id] = blk
        @writer.write(id: id, method: method, params: params)
      end

      def on_text_changed(uri, version)
        if @open_texts[uri]
          rb = @open_texts[uri]
          @config.rb_files = [[URI(uri).path, rb.text]]
          @config.rbs_files = ["typeprof.rbs"] # XXX
          @config.verbose = 0
          @config.max_sec = 1
          @config.options[:show_errors] = true
          @config.options[:show_indicator] = false
          @config.options[:lsp] = true

          res, definition_table = TypeProf.analyze(@config)

          @open_texts[uri].definition_table = definition_table

          sigs = {}
          res[:sigs].each do |file, lineno, sig, rbs_code_range|
            uri = "file://" + file
            sigs[uri] ||= []
            command = { title: sig }
            if rbs_code_range
              command[:command] = "jump_to_rbs"
              command[:arguments] = [uri, { line: lineno - 1, character: 0 }, "file:///home/mame/work/rbswiki/" + rbs_code_range[0], rbs_code_range[1].to_lsp]
            end
            sigs[uri] << {
              range: {
                start: { line: lineno - 1, character: 0 },
                end: { line: lineno - 1, character: 1 },
              },
              command: command,
            }
          end
          @sigs = sigs

          diagnostics = {}
          res[:errors].each do |(file, code_range), msg|
            next unless file
            uri = "file://" + file
            diagnostics[uri] ||= []
            diagnostics[uri] << {
              range: code_range.to_lsp,
              severity: 1,
              source: "TypeProf",
              message: msg,
            }
          end
          @diagnostics = diagnostics
        
          send_request("workspace/codeLens/refresh")

          send_notification(
            "textDocument/publishDiagnostics",
            {
              uri: uri,
              version: version,
              diagnostics: diagnostics[uri] || [],
            }
          )
        end
      rescue SyntaxError
      end
    end
  end
end
