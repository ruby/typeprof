def foo(n:, s:)
  [n, s]
end

foo(n: 42, s: "str")

__END__
# Classes
class Object
  foo : (n: Integer, s: String) -> [Integer, String]
end
