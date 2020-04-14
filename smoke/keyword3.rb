# TODO: foo should accept "s: String | [Integer]"?
def foo(n: 42, s: [n])
  [n, s]
end

foo(n: 42, s: "str")

__END__
# Classes
class Object
  def foo : (?n: Integer, ?s: String) -> ([Integer, String | [Integer]])
end
