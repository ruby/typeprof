# update: test.rbs
type a = Integer
class Foo
  type a = Integer | String
  def foo: (a) -> a
end

# update: test.rb
def test1
  Foo.new.foo(1)
end

def test2
  Foo.new.foo("str")
end

def test3(unknown)
  Foo.new.foo(unknown)
end

# assert: test.rb
class Object
  def test1: -> (Integer | String)
  def test2: -> (Integer | String)
  def test3: (untyped) -> untyped
end

# update: test.rbs
type a = Integer
class Foo
  type a = Integer | String
  def foo: (::a) -> ::a
end

# assert: test.rb
class Object
  def test1: -> Integer
  def test2: -> untyped
  def test3: (untyped) -> untyped
end

# update: test.rbs
type a = Integer
class Foo
  def foo: (a) -> a
end

# assert: test.rb
class Object
  def test1: -> Integer
  def test2: -> untyped
  def test3: (untyped) -> untyped
end

# update: test.rbs
class Bar
  type a = Integer
end
class Foo
  def foo: (Bar::a) -> Bar::a
end

# assert: test.rb
class Object
  def test1: -> Integer
  def test2: -> untyped
  def test3: (untyped) -> untyped
end