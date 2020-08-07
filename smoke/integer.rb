def foo(x); end

foo(Integer(1))
foo(Integer("str"))

__END__
# Classes
class Object
  def foo : (Integer) -> nil
end
