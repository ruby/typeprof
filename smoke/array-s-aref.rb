def foo
  Array[42, "str"]
end

foo

__END__
# Classes
class Object
  def foo : () -> (Array[Integer | String])
end
