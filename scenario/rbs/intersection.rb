## update: test.rbs
interface _Readable
  def read: () -> String
end

interface _Writable
  def write: (String) -> void
end

class Processor
  def process: (_Readable & _Writable) -> String
end

## update: test.rb
class MyIO
  def read
    "content"
  end

  def write(text)
    text
  end
end

class Processor
  def process_file
    io = MyIO.new
    process(io)
  end
end

## assert: test.rb
class MyIO
  def read: -> String
  def write: (untyped) -> untyped
end
class Processor
  def process_file: -> String
end
