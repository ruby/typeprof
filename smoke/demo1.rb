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
  def foo : (bool) -> (Integer | String)
end
