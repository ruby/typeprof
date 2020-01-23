def foo(a)
  a.map {|n| rand < 0.5 ? n.to_s : n }
end

foo([1, 2, 3])
__END__
# Classes
class Object
  foo : ([Integer, Integer, Integer]) -> (Array[Integer | String])
end
