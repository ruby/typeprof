## update
class Foo
end

#: -> singleton(Foo)
def test
  1
end

## diagnostics
(6,2)-(6,3): expected: singleton(::Foo); actual: Integer
