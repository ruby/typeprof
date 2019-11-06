def foo(x)
  if x
    42
  else
    "str"
  end
end

foo(true)
foo(false)

__END__
# Classes
class Object
  foo : (Boolean) -> (Integer | String)
end
