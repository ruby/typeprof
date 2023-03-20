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

    def log(msg)
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

  class Message::CancelRequest < Message
    METHOD = "$/cancelRequest" # notification
    def run
      @server.cancel_request(@params[:id])
    end
  end

  class Message::Initialize < Message
    METHOD = "initialize" # request (required)
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

      log "TypeProf for IDE is started successfully"
    end
  end

  class Message::Initialized < Message
    METHOD = "initialized" # notification
    def run
    end
  end

  class Message::Shutdown < Message
    METHOD = "shutdown" # request (required)
    def run
      respond(nil)
    end
  end

  class Message::Exit < Message
    METHOD = "exit" # notification
    def run
      @server.exit
    end
  end

  module Message::TextDocument
  end

  class Message::TextDocument::DidOpen < Message
    METHOD = "textDocument/didOpen" # notification
    def run
      @params => { textDocument: { uri:, version:, text: } }

      text = Text.new(URI(uri).path, text, version)
      @server.open_texts[uri] = text
      @server.core.update_file(text.path, text.text)
    end
  end

  class Message::TextDocument::DidChange < Message
    METHOD = "textDocument/didChange" # notification
    def run
      @params => { textDocument: { uri:, version: }, contentChanges: changes }
      text = @server.open_texts[uri]
      text.apply_changes(changes, version)
      @server.core.update_file(text.path, text.text)
    end
  end

  # textDocument/willSave notification
  # textDocument/willSaveWaitUntil request
  # textDocument/didSave notification

  class Message::TextDocument::DidClose < Message
    METHOD = "textDocument/didClose" # notification
    def run
      @params => { textDocument: { uri: } }
      text = @server.open_texts.delete(uri)
      @server.core.update_file(text.path, nil)
    end
  end

  # textDocument/declaration request

  class Message::TextDocument::Definition < Message
    METHOD = "textDocument/definition" # request
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

  # textDocument/references request

  class Message::TextDocument::Hover < Message
    METHOD = "textDocument/hover" # request
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

  # textDocument/codeLens request
  # workspace/codeLens/refresh request (server-to-client)

  # textDocument/documentSymbol request

  # textDocument/publishDiagnostics notification (server-to-client)

  # textDocument/diagnostic request
  # workspace/diagnostic request
  #   workspace/diagnostic/refresh request

  # textDocument/completion request
  #   completionItem/resolve request

  # textDocument/signatureHelp request

  # textDocument/rename request
  # textDocument/prepareRename request

  # workspace/symbol request
  #   workspaceSymbol/resolve request

  # workspace/didChangeWatchedFiles notification

  # workspace/executeCommand request

  Message.build_table
end