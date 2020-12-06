def map_test(a)
  a.map {|n| n.to_s }
end
def map_bang_test(a)
  a.map! {|n| n.to_s }
  a
end
def map_bang_test_known_bug(a)
  a.map! {|n| n.to_s }
end

map_test([1, 2, 3])
map_bang_test([1, 2, 3])
map_bang_test_known_bug([1, 2, 3])

__END__
# Classes
class Object
  private
  def map_test: ([Integer, Integer, Integer]) -> Array[String]
  def map_bang_test: ([Integer, Integer, Integer]) -> (Array[Integer | String])
  def map_bang_test_known_bug: ([Integer, Integer, Integer]) -> [Integer, Integer, Integer]
end
