module Net
  class HTTP
    class IOError < StandardError; end

    def start  # :yield: http
      raise IOError, 'HTTP session already opened' if @started
      if block_given?
        begin
          do_start
          return yield(self)
        ensure
          do_finish
        end
      end
      do_start
      self
    end

    def do_start
    end

    def do_finish
    end
  end
end
