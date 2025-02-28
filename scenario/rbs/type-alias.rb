## update: test.rbs
type a = Integer
class Foo
  type a = Integer | String
  def foo: (a) -> a
end

## update: test.rb
def test1
  Foo.new.foo(1)
end

def test2
  Foo.new.foo("str")
end

def test3(unknown)
  Foo.new.foo(unknown)
end

## assert: test.rb
class Object
  def test1: -> (Integer | String)
  def test2: -> (Integer | String)
  def test3: (untyped) -> (Integer | String)
end

## diagnostics: test.rb
(10,10)-(10,13): wrong type of arguments

## update: test.rbs
type a = Integer
class Foo
  type a = Integer | String
  def foo: (::a) -> ::a
end

## assert: test.rb
class Object
  def test1: -> Integer
  def test2: -> Integer
  def test3: (untyped) -> Integer
end

## diagnostics: test.rb
(6,10)-(6,13): wrong type of arguments
(10,10)-(10,13): wrong type of arguments

## update: test.rbs
type a = Integer
class Foo
  def foo: (a) -> a
end

## assert: test.rb
class Object
  def test1: -> Integer
  def test2: -> Integer
  def test3: (untyped) -> Integer
end

## diagnostics: test.rb
(6,10)-(6,13): wrong type of arguments
(10,10)-(10,13): wrong type of arguments

## update: test.rbs
class Bar
  type a = Integer
end
class Foo
  def foo: (Bar::a) -> Bar::a
end

## assert: test.rb
class Object
  def test1: -> Integer
  def test2: -> Integer
  def test3: (untyped) -> Integer
end

## diagnostics: test.rb
(6,10)-(6,13): wrong type of arguments
(10,10)-(10,13): wrong type of arguments
