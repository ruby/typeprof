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
  def foo : () -> (Array[Integer | String])
end
