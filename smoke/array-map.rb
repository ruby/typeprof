def foo(a)
  a.map {|n| n.to_s }
end

foo([1, 2, 3])

__END__
# Classes
class Object
  foo : ([Integer, Integer, Integer]) -> Array[String]
end
