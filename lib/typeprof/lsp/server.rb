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

    def initialize(core, reader, writer)
      @core = core
      @reader = reader
      @writer = writer
      @request_id = 0
      @running_requests_from_client = {}
      @running_requests_from_server = {}
      @open_texts = {}
      @exit = false
      @signature_enabled = true
    end

    attr_reader :core, :open_texts
    attr_accessor :signature_enabled

    def target_path?(path)
      # XXX: hard-coded for dog-fooding
      return true if path.start_with?(File.join(File.dirname(File.dirname(File.dirname(__dir__))), "sig"))
      return false if !path.start_with?(File.dirname(__dir__))
      return false if path.start_with?(File.join(File.dirname(__dir__), "lsp"))
      return true
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