def foo(a, b, c)
  [a, b, c]
end

a = [1, "S", :s]
foo(*a)

#def bar(a, b, c)
#  [a, b,  d]
#end
#def baz(a, b, c)
#  [a, b,  d]
#end
#def qux(a, b, c)
#  [a, b,  d]
#end
#a = ["S", :s]
#bar(1, *a)

#a = ["S"] + [:s]
#baz(1, *a)

#a = [1, "S"]
#qux(*a, :s)

__END__
# Classes
class Object
  foo : (Integer, Integer, Integer) -> [Integer, Integer, Integer]
      | (Integer, Integer, String) -> [Integer, Integer, String]
      | (Integer, Integer, Symbol) -> [Integer, Integer, Symbol]
      | (Integer, String, Integer) -> [Integer, String, Integer]
      | (Integer, String, String) -> [Integer, String, String]
      | (Integer, String, Symbol) -> [Integer, String, Symbol]
      | (Integer, Symbol, Integer) -> [Integer, Symbol, Integer]
      | (Integer, Symbol, String) -> [Integer, Symbol, String]
      | (Integer, Symbol, Symbol) -> [Integer, Symbol, Symbol]
      | (String, Integer, Integer) -> [String, Integer, Integer]
      | (String, Integer, String) -> [String, Integer, String]
      | (String, Integer, Symbol) -> [String, Integer, Symbol]
      | (String, String, Integer) -> [String, String, Integer]
      | (String, String, String) -> [String, String, String]
      | (String, String, Symbol) -> [String, String, Symbol]
      | (String, Symbol, Integer) -> [String, Symbol, Integer]
      | (String, Symbol, String) -> [String, Symbol, String]
      | (String, Symbol, Symbol) -> [String, Symbol, Symbol]
      | (Symbol, Integer, Integer) -> [Symbol, Integer, Integer]
      | (Symbol, Integer, String) -> [Symbol, Integer, String]
      | (Symbol, Integer, Symbol) -> [Symbol, Integer, Symbol]
      | (Symbol, String, Integer) -> [Symbol, String, Integer]
      | (Symbol, String, String) -> [Symbol, String, String]
      | (Symbol, String, Symbol) -> [Symbol, String, Symbol]
      | (Symbol, Symbol, Integer) -> [Symbol, Symbol, Integer]
      | (Symbol, Symbol, String) -> [Symbol, Symbol, String]
      | (Symbol, Symbol, Symbol) -> [Symbol, Symbol, Symbol]
end
