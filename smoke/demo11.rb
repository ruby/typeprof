def swap(a)
  [a[1], a[0]]
end
a = [42, "str"]
swap(a)

__END__
# Classes
class Object
  swap : ([Integer, String]) -> [String, Integer]
end
