module TypeProf::LSP
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

    def respond_error(error)
      raise "do not respond to notification" if @id == nil
      @server.send_response(id: @id, error: error)
    end

    Classes = []
    def self.inherited(klass)
      Classes << klass
    end

    Table = Hash.new(Message)
    def self.build_table
      Classes.each do |klass|
        Table[klass::METHOD] = klass
      end
    end

    def self.find(method)
      Table[method]
    end
  end

  module ErrorCodes
    ParseError = -32700
    InvalidRequest = -32600
    MethodNotFound = -32601
    InvalidParams = -32602
    InternalError = -32603
  end

  class Message::Initialize < Message
    METHOD = "initialize"
    def run
      folders = @params[:workspaceFolders].map do |folder|
        folder => { uri:, }
        URI(uri).path
      end

      @server.core.add_workspaces(folders)

      respond(
        capabilities: {
          textDocumentSync: {
            openClose: true,
            change: 2, # Incremental
          },
          hoverProvider: true,
          definitionProvider: true,
          #completionProvider: {
          #  triggerCharacters: ["."],
          #},
          #signatureHelpProvider: {
          #  triggerCharacters: ["(", ","],
          #},
          #codeActionProvider: {
          #  codeActionKinds: ["quickfix", "refactor"],
          #  resolveProvider: false,
          #},
          #codeLensProvider: {
          #  resolveProvider: true,
          #},
          executeCommandProvider: {
            commands: [
              "typeprof.createPrototypeRBS",
              "typeprof.enableSignature",
              "typeprof.disableSignature",
            ],
          },
          #typeDefinitionProvider: true,
          #referencesProvider: true,
        },
        serverInfo: {
          name: "typeprof",
          version: TypeProf::VERSION,
        },
      )

      puts "TypeProf for IDE is started successfully"
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

  class Message::Exit < Message
    METHOD = "exit"
    def run
      exit
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
      @params => { textDocument: { uri:, version:, text: } }

      text = Text.new(@server, URI(uri).path, text, version)
      @server.open_texts[uri] = text
      @server.core.update_file(text.path, text.text)
    end
  end

  class Message::TextDocument::DidChange < Message
    METHOD = "textDocument/didChange"
    def run
      @params => { textDocument: { uri:, version: }, contentChanges: changes }
      text = @server.open_texts[uri]
      text.apply_changes(changes, version)
      @server.core.update_file(text.path, text.text)
    end
  end

  class Message::TextDocument::DidClose < Message
    METHOD = "textDocument/didClose"
    def run
      @params => { textDocument: { uri: } }
      @server.open_texts.delete(uri)
      @server.core.update_file(text.path, nil)
    end
  end

  class Message::TextDocument::Hover < Message
    METHOD = "textDocument/hover"
    def run
      @params => {
        textDocument: { uri: },
        position: pos,
      }
      text = @server.open_texts[uri]
      str = @server.core.hover(text.path, TypeProf::CodePosition.from_lsp(pos))
      if str
        respond(contents: { language: "ruby", value: str })
      else
        respond(nil)
      end
    end
  end

  class Message::TextDocument::Definition < Message
    METHOD = "textDocument/definition"
    def run
      @params => {
        textDocument: { uri: },
        position: pos,
      }
      text = @server.open_texts[uri]
      defs = @server.core.definitions(text.path, TypeProf::CodePosition.from_lsp(pos))
      if defs.empty?
        respond(nil)
      else
        respond(defs.map do |path, code_range|
          {
            uri: "file://" + path,
            range: code_range.to_lsp,
          }
        end)
      end
    end
  end

  class Message::CancelRequest < Message
    METHOD = "$/cancelRequest"
    def run
      @server.cancel_request(@params[:id])
    end
  end

  Message.build_table
end