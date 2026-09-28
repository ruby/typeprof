## update
define_method(:foo) do |x|
  super
end

## diagnostics
(1,0)-(1,13): undefined method: Object#define_method
(2,2)-(2,7): implicit argument passing of super from method defined by define_method() is not supported

## update
class Foo
  define_method(:foo) { super() }
end

## diagnostics

## update
class Base
  def bar = 1
end
class Foo < Base
  def self.make
    define_method(:bar) { super() }
    define_singleton_method(:baz) { super }
  end
end

## diagnostics
(7,36)-(7,41): implicit argument passing of super from method defined by define_method() is not supported

## update
super
super()

class C
  super
  [1].each { super() }
end

## diagnostics
(1,0)-(1,5): super called outside of method
(2,0)-(2,7): super called outside of method
(5,2)-(5,7): super called outside of method
(6,13)-(6,20): super called outside of method

## update
def pr(*a, **k) = a

class C
  def self.m(...)
    define_method(:x) { pr(...) }
  end

  m(1, 2)
end

## diagnostics
