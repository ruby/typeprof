module TypeProf::LSP
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

    class Exit < StandardError; end

    def initialize(core, reader, writer)
      @core = core
      @reader = reader
      @writer = writer
      @request_id = 0
      @running_requests_from_client = {}
      @running_requests_from_server = {}
      @open_texts = {}
    end

    attr_reader :core, :open_texts

    def run
      @reader.read do |json|
        if json[:method]
          # request or notification
          msg = Message.find(json[:method]).new(self, json)
          @running_requests_from_client[json[:id]] = msg if json[:id]
          msg.run
        else
          # response
          callback = @running_requests_from_server.delete(json[:id])
          callback&.call(json[:params])
        end
      end
    rescue Exit
    end

    def send_response(**msg)
      @running_requests_from_client.delete(msg[:id])
      @writer.write(**msg)
    end

    def send_notification(method, params = nil)
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