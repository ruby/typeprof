def foo(n)
  n.class
end

foo(1)
foo("")

__END__
# Classes
class Object
  def foo : (Integer | String) -> (Integer.class | String.class)
end
