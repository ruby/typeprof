## update
def foo
  yield 1
  "str"
end

def bar
  foo do |n|
    break
    1.0
  end
end

# TODO: These expectation are wrong! Need to implement break correctly

## assert
class Object
  def foo: { (Integer) -> Float } -> String
  def bar: -> String?
end

## update: test.rb
def foo
  loop do
    break 1
  end
end

## assert
class Object
  def foo: -> Integer
end
