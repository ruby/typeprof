## update: test.rbs
class Object
  def bar: (Binding?) -> void
end

## update: test.rb
eval("hello", nil, "test")

def bar_nil
  bar(nil)
end

def bar_binding
  bar(binding)
end

## assert
class Object
  def bar_nil: -> Object
  def bar_binding: -> Object
end
