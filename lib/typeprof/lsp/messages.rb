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

    def notify(method, **params)
      @server.send_notification(method, **params)
    end

    def publish_diagnostics(uri)
      text = @server.open_texts[uri]
      diags = []
      if text
        @server.core.diagnostics(text.path) do |diag|
          diags << diag.to_lsp
        end
      end
      notify(
        "textDocument/publishDiagnostics",
        uri: uri,
        diagnostics: diags
      )
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
          completionProvider: {
            triggerCharacters: [".", ":"],
          },
          #signatureHelpProvider: {
          #  triggerCharacters: ["(", ","],
          #},
          codeLensProvider: {
            resolveProvider: false,
          },
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

      path = URI(uri).path
      return unless @server.target_path?(path)

      text = Text.new(path, text, version)
      @server.open_texts[uri] = text
      @server.core.update_file(text.path, text.string)
      @server.send_request("workspace/codeLens/refresh")
      publish_diagnostics(uri)
    end
  end

  class Message::TextDocument::DidChange < Message
    METHOD = "textDocument/didChange" # notification
    def run
      @params => { textDocument: { uri:, version: }, contentChanges: changes }
      text = @server.open_texts[uri]
      return unless text
      text.apply_changes(changes, version)
      @server.core.update_file(text.path, text.string)
      @server.send_request("workspace/codeLens/refresh")
      publish_diagnostics(uri)
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
      return unless text
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
      unless text
        respond(nil)
        return
      end
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
      unless text
        respond(nil)
        return
      end
      str = @server.core.hover(text.path, TypeProf::CodePosition.from_lsp(pos))
      if str
        respond(contents: { language: "ruby", value: str })
      else
        respond(nil)
      end
    end
  end

  class Message::TextDocument::CodeLens < Message
    METHOD = "textDocument/codeLens"
    def run
      @params => { textDocument: { uri: } }
      text = @server.open_texts[uri]
      unless text
        respond(nil)
        return
      end
      ret = []
      @server.core.code_lens(text.path) do |code_range, title|
        ret << {
          range: code_range.to_lsp,
          command: {
            title: title,
            command: "typeprof.jumpToRBS",
          },
        }
      end
      respond(ret)
    end
  end

  # textDocument/documentSymbol request

  # textDocument/diagnostic request
  # workspace/diagnostic request
  #   workspace/diagnostic/refresh request

  class Message::TextDocument::Completion < Message
    METHOD = "textDocument/completion"
    def run
      @params => {
        textDocument: { uri: },
        position: pos,
      }
      #trigger_kind = @params.key?(:context) ? @params[:context][:triggerKind] : 1 # Invoked
      text = @server.open_texts[uri]
      unless text
        respond(nil)
        return
      end
      items = []
      sort = "aaaa"
      text.modify_for_completion(text, pos) do |string, trigger, pos|
        @server.core.update_file(text.path, string)
        pos = TypeProf::CodePosition.from_lsp(pos)
        @server.core.completion(text.path, trigger, pos) do |mid, hint|
          items << {
            label: mid,
            kind: 2, # Method
            sortText: sort,
            detail: hint,
          }
          sort = sort.succ
        end
      end
      respond(
        isIncomplete: false,
        items: items,
      )
      @server.core.update_file(text.path, text.string)
    end
  end

  # textDocument/signatureHelp request

  # textDocument/rename request
  # textDocument/prepareRename request

  # workspace/symbol request
  #   workspaceSymbol/resolve request

  # workspace/didChangeWatchedFiles notification

  # workspace/executeCommand request

  Message.build_table
end