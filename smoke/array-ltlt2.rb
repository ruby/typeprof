def foo
  a = []
  while true
    a << 1
    a << "str"
    break if rand < 0.5
  end
  a
end

foo
__END__
# Classes
class Object
  foo : () -> (Array[Integer | NilClass | String])
end
