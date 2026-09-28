## update
define_method(:foo) do |x|
  super
end

## diagnostics
(1,0)-(1,13): undefined method: Object#define_method
(2,2)-(2,7): implicit argument passing of super is not supported here

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
(7,36)-(7,41): implicit argument passing of super is not supported here
