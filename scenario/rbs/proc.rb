## update: test.rbs
class Foo
  @proc: ^() -> Integer

  def set_proc: (^(String) -> Integer) -> void
  def get_proc: () -> ^() -> String
end

## update: test.rb
class Foo
  def initialize
    @proc = -> { 42 }
  end

  def set_proc(p)
    @proc = p
  end

  def get_proc
    -> { "hello" }
  end
end

## assert
class Foo
  def initialize: -> Proc
  def set_proc: (Proc) -> (Object | Proc)
  def get_proc: -> Proc
end

## update: test.rbs
class Object
  def take_proc: (^(Integer) -> String) -> void
  def call_proc: (^() -> Integer) -> Integer
end

## update: test.rb
def take_proc(p)
  p.call(42)
end

def call_proc(p)
  p.call
end

## assert
class Object
  def take_proc: (Proc) -> Object
  def call_proc: (Proc) -> Integer
end

## update: test.rbs
class Bar
  def with_block: () { () -> Integer } -> void
  def proc_arg: (^(String) -> Integer) -> Integer
end

## update: test.rb
class Bar
  def with_block(&block)
    block.call
  end

  def proc_arg(p)
    p.call("test")
  end
end

## assert
class Bar
  def with_block: { () -> untyped } -> Object
  def proc_arg: (Proc) -> Integer
end
