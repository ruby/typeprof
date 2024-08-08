## update
class Foo
  def gen
    [1]
  end

  def check
    ary = []
    ary.append(*gen)
    ary.append(*gen)
  end
end

## assert
class Foo
  def gen: -> [Integer]
  def check: -> Array[Integer]
end
