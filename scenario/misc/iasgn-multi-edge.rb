## update
class Foo
  def foo(n)
    # assigning the same lvar to an ivar multiple times
    # may make multi-edge from the lvar to the ivar
    @x = n
    @x = n
  end
end

## assert
class Foo
  def foo: (untyped) -> untyped
end