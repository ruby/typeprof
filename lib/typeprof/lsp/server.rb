module TypeProf::LSP
  module ErrorCodes
    ParseError = -32700
    InvalidRequest = -32600
    MethodNotFound = -32601
    InvalidParams = -32602
    InternalError = -32603
  end

  class Server
    def self.start_stdio(core)
      $stdin.binmode
      $stdout.binmode
      reader = Reader.new($stdin)
      writer = Writer.new($stdout)
      # pipe all builtin print output to stderr to avoid conflicting with lsp
      $stdout = $stderr
      new(core, reader, writer).run
    end

    def self.start_socket(core)
      Socket.tcp_server_sockets("localhost", nil) do |servs|
        serv = servs[0].local_address
        $stdout << JSON.generate({
          host: serv.ip_address,
          port: serv.ip_port,
          pid: $$,
        })
        $stdout.flush

        $stdout = $stderr

        Socket.accept_loop(servs) do |sock|
          sock.set_encoding("UTF-8")
          begin
            reader = Reader.new(sock)
            writer = Writer.new(sock)
            new(core, reader, writer).run
          ensure
            sock.close
          end
          exit
        end
      end
    end

    def initialize(core, reader, writer, url_schema: nil, publish_all_diagnostics: false)
      @core = core
      @workspaces = {}
      @reader = reader
      @writer = writer
      @request_id = 0
      @running_requests_from_client = {}
      @running_requests_from_server = {}
      @open_texts = {}
      @exit = false
      @signature_enabled = true
      @url_schema = url_schema || (File::ALT_SEPARATOR != "\\" ? "file://" : "file:///")
      @publish_all_diagnostics = publish_all_diagnostics # TODO: implement more dedicated publish feature
    end

    attr_reader :core, :open_texts
    attr_accessor :signature_enabled

    def path_to_uri(path)
      @url_schema + File.expand_path(path)
    end

    def uri_to_path(url)
      url.delete_prefix(@url_schema)
    end

    def add_workspaces(folders)
      folders.each do |path|
        conf_path = File.join(path, "typeprof.conf.json")
        if File.readable?(conf_path)
          conf = TypeProf::LSP.load_json_with_comments(conf_path, symbolize_names: true)
          if conf
            if conf[:typeprof_version] == "experimental"
              if conf[:analysis_unit_dirs].size >= 2
                 puts "currently analysis_unit_dirs can have only one directory"
              end
              conf[:analysis_unit_dirs].each do |dir|
                dir = File.expand_path(dir, path)
                @workspaces[dir] = true
                @core.add_workspace(dir, conf[:rbs_dir])
              end
            else
              puts "Unknown typeprof_version: #{ conf[:typeprof_version] }"
            end
          end
        else
          puts "typeprof.conf.json is not found"
        end
      end
    end

    def target_path?(path)
      @workspaces.each do |folder, _|
        return true if path.start_with?(folder)
      end
      return false
    end

    def run
      @reader.read do |json|
        if json[:method]
          # request or notification
          msg_class = Message.find(json[:method])
          if msg_class
            msg = msg_class.new(self, json)
            @running_requests_from_client[json[:id]] = msg if json[:id]
            msg.run
          else

          end
        else
          # response
          callback = @running_requests_from_server.delete(json[:id])
          callback&.call(json[:params], json[:error])
        end
        break if @exit
      end
    end

    def send_response(**msg)
      @running_requests_from_client.delete(msg[:id])
      @writer.write(**msg)
    end

    def send_notification(method, **params)
      @writer.write(method: method, params: params)
    end

    def send_request(method, **params, &blk)
      id = @request_id += 1
      @running_requests_from_server[id] = blk
      @writer.write(id: id, method: method, params: params)
    end

    def cancel_request(id)
      req = @running_requests_from_client[id]
      req.cancel if req.respond_to?(:cancel)
    end

    def exit
      @exit = true
    end

    def publish_diagnostics(uri)
      (@publish_all_diagnostics ? @open_texts : [[uri, @open_texts[uri]]]).each do |uri, text|
        diags = []
        if text
          @core.diagnostics(text.path) do |diag|
            diags << diag.to_lsp
          end
        end
        send_notification(
          "textDocument/publishDiagnostics",
          uri: uri,
          diagnostics: diags
        )
      end
    end
  end

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
      @mutex = Mutex.new
    end

    def write(**json)
      json = JSON.generate(json.merge(jsonrpc: "2.0"))
      @mutex.synchronize do
        @io << "Content-Length: #{ json.bytesize }\r\n\r\n" << json
        @io.flush
      end
    end
  end
end
