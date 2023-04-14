# update
def test(x)
  return if x == :foo
end

test(:foo)
test(:bar)

# diagnostics

# assert
class Object
  def test: (:bar | :foo) -> nil
end