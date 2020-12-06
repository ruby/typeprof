def foo(o1=1, *r)
  [r]
end

foo()
foo("x", "x")
__END__
# Classes
class Object
  private
  def foo: (?Integer | String, *String) -> [Array[String]]
end
