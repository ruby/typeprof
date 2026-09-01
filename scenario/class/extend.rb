## update
module A
  def a = 1
end
module B
  def b = "s"
end
class C
  extend A
  extend B
end

def f = [C.a, C.b]

## assert
module A
  def a: -> Integer
end
module B
  def b: -> String
end
class C
  extend A
  extend B
end
class Object
  def f: -> [Integer, String]
end

## update
module M
  def hi = "from M"
end
class C
  extend M
  def self.hi = 42
end

def f = C.hi

## assert
module M
  def hi: -> String
end
class C
  extend M
  def self.hi: -> Integer
end
class Object
  def f: -> Integer
end

## update
module Inner
  def deep = 1.0
end
module Outer
  include Inner
end
class C
  extend Outer
end

def f = C.deep

## assert
module Inner
  def deep: -> Float
end
module Outer
end
class C
  extend Outer
end
class Object
  def f: -> Float
end
