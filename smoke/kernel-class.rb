def foo(n)
  n.class
end

foo(1)
foo("")

__END__
# Classes
class Object
  foo : (Integer) -> (Integer.class | String.class)
      | (String) -> (Integer.class | String.class)
end
