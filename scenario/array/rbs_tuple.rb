## update
def foo
  {
    a: 1,
    b: "str",
  }.to_a
end

def bar
  [1, 2, 3].minmax
end

def baz
  ret = nil
  %w(foo bar baz).each_with_index do |x, i|
    ret = i
  end
  ret
end

## assert
class Object
  def foo: -> Array[[:a | :b, Integer | String]]
  def bar: -> [Integer?, Integer?]
  def baz: -> Integer?
end