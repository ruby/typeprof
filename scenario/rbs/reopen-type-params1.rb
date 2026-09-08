## update: test.rbs
module Foo[E] : _Each[E]
  def first_e: () -> E
end

class C
  include Foo[Integer]
  def each: () { (Integer) -> void } -> void
end

## update: test2.rbs
# Reopen with a different type parameter name
module Foo[X] : _Each[X]
  def first_x: () -> X
  def with_x: (X) -> X
end

## update: test.rb
def f = C.new.first_e
def g = C.new.first_x
def h = C.new.with_x(1)

## assert
class Object
  def f: -> Integer
  def g: -> Integer
  def h: -> Integer
end
