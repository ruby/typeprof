## update
class Foo
  attr_reader :a
  attr_accessor :b
  attr_writer :c
  alias set_c c=
end
foo = Foo.new
foo.a(k: 1)
foo.b(k: 1)
foo.set_c(k: 1)

## assert
class Foo
  def a: -> untyped
  def b: -> untyped
  def b=: (untyped) -> untyped
  def c=: ({ k: Integer }) -> { k: Integer }
end

## diagnostics
(8,4)-(8,5): wrong number of arguments (1 for 0)
(9,4)-(9,5): wrong number of arguments (1 for 0)
