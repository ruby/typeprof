# Currently, flow sensitive analysis does not work!  Need work...
def foo(n)
  if n.is_a?(Integer)
    n + 1
  else
    n + "STR"
  end
end

foo(42)
foo("str")

__END__
# Errors
smoke/flow1.rb:6: [error] failed to resolve overload: Integer#+
smoke/flow1.rb:6: [error] failed to resolve overload: Integer#+
# Classes
class Object
  def foo : (Integer | String) -> (Integer | String | any)
end
