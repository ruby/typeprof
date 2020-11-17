def foo(n)
  n.class
end

foo(1)
foo("")

__END__
# Classes
class Object
  def foo : (Integer | String) -> (singleton(Integer) | singleton(String))
end
