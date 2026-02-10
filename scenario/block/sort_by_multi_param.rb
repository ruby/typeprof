## update
def foo
  { a: 1 }.sort_by do |key_value|
    key_value
  end
end

def bar
  { a: 1 }.sort_by do |key, value|
    key
  end
end

def baz
  { a: 1 }.sort_by do |(key, value)|
    key
  end
end

## assert
class Object
  def foo: -> Array[[:a, Integer]]
  def bar: -> Array[[:a, Integer]]
  def baz: -> Array[[:a, Integer]]
end

## update
def foo
  { 'a' => 1 }.sort_by do |key_value|
    key_value
  end
end

def bar
  { 'a' => 1 }.sort_by do |key, value|
    key
  end
end

def baz
  { 'a' => 1 }.sort_by do |(key, value)|
    key
  end
end

## assert
class Object
  def foo: -> Array[[String, Integer]]
  def bar: -> Array[[String, Integer]]
  def baz: -> Array[[String, Integer]]
end
