def foo(x)
  if x
    x + 1
  end
end

foo(1)
foo(nil)

__END__
# Classes
class Object
  def foo : (Integer | NilClass) -> (Integer | NilClass)
end
