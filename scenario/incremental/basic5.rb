## update: test0.rb
def foo(n, &b)
  b.call(1.0)
end

## update: test1.rb
def bar(_)
  foo(12) do |n|
    "str"
  end
end

def baz(_)
  foo(12) do |n|
    "str"
  end
end

## assert_without_validation: test0.rb
class Object
  def foo: (Integer) { (Float) -> String } -> String
end

## update: test1.rb
def bar(_)
  foo(12) do |n|
    1
  end
end

def baz(_)
  foo(12) do |n|
    "str"
  end
end

## assert_without_validation: test0.rb
class Object
  def foo: (Integer) { (Float) -> (Integer | String) } -> (Integer | String)
end

## update: test1.rb
def bar(_)
  foo(12) do |n|
    1
  end
end

def baz(_)
  foo(12) do |n|
    1
  end
end

## assert_without_validation: test0.rb
class Object
  def foo: (Integer) { (Float) -> Integer } -> Integer
end
