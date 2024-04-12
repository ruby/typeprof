## update: test.rbs
class Object
  def foo: { ([Integer, String]) -> void } -> void
end

## update: test.rb
def test_first
  foo do |n, _s|
    return n
  end
  nil
end

def test_second
  foo do |_n, s|
    return s
  end
  nil
end

## assert
class Object
  def test_first: -> Integer?
  def test_second: -> String?
end
