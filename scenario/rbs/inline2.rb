## update
class C
  #: (Array[untyped]) -> Array[untyped]
  def foo(x)
    x
  end
end

## assert
class C
  def foo: (Array[untyped]) -> Array[untyped]
end
