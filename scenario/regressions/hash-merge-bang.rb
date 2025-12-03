## update
def option
  { a: 1 }
end

def foo1
  option.merge!(bar)
end

def foo2
  option.merge!(bar)
end

def bar = {}

## assert
class Object
  def option: -> Hash[:a, Integer]
  def foo1: -> Hash[:a, Integer]
  def foo2: -> Hash[:a, Integer]
  def bar: -> Hash[untyped, untyped]
end
