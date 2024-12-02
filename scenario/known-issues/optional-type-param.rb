## update: test.rbs
interface _Foo[X, Y = Integer]
  def initialize: (X) -> void
end

class Object
  def get_foo_str: -> _Foo[String]
  def accept_foo_str: (_Foo[String]) -> void
end

## update: test.rb
accept_foo_str(get_foo_st)

## assert
