def foo
  a = [1]
  a[1] = "str"
  a
end

foo

__END__
# Classes
class Object
  def foo : -> (Array[Integer | String])
end
