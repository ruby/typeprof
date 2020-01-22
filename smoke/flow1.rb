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
smoke/flow1.rb:3: [error] failed to resolve overload: String#+
smoke/flow1.rb:5: [error] failed to resolve overload: Integer#+
# Classes
class Object
  foo : (Integer | String) -> (Integer | String | any)
end
