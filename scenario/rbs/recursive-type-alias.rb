## update: test.rbs
# Basic recursive type alias
type context = nil | [context, bool]

class C
  def foo: -> context
end

## update: test.rb
def test1
  C.new.foo
end

## assert: test.rb
class Object
  def test1: -> [untyped, bool]?
end

## diagnostics: test.rb

## update: test.rbs
# Recursive type alias in class scope
class D
  type tree = Integer | [tree, tree]
  def get_tree: -> tree
end

## update: test.rb
def test2
  D.new.get_tree
end

## assert: test.rb
class Object
  def test2: -> (Integer | [untyped, untyped])
end

## diagnostics: test.rb

## update: test.rbs
# Mutually recursive type aliases
type node = [Integer, nodes]
type nodes = Array[node]

class E
  def build_tree: -> node
end

## update: test.rb
def test3
  E.new.build_tree
end

## assert: test.rb
class Object
  def test3: -> [Integer, Array[untyped]]
end

## diagnostics: test.rb

## update: test.rbs
# Recursive type alias with generic parameters
type list[T] = nil | [T, list[T]]

class F
  def create_list: -> list[String]
end

## update: test.rb
def test4
  F.new.create_list
end

## assert: test.rb
class Object
  def test4: -> [String, untyped]?
end

## diagnostics: test.rb
