## update
class Foo
  def rest(*args)
    args
  end

  def call_rest_method
    rest(1)
  end
end

## assert
class Foo
  def rest: (*Integer) -> Array[Integer]
  def call_rest_method: -> Array[Integer]
end
