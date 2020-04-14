def foo(x)
  yield 42
end

s = "str"
foo(1) do |x|
  s
end

__END__
# Classes
class Object
  def foo : (Integer) { (Integer) -> String } -> String
end
