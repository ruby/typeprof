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
Object#foo :: (Integer, Integer, Integer) -> [Integer, Integer, Integer]
Object#foo :: (Integer, Integer, String) -> [Integer, Integer, String]
Object#foo :: (Integer, Integer, Symbol) -> [Integer, Integer, Symbol]
Object#foo :: (Integer, String, Integer) -> [Integer, String, Integer]
Object#foo :: (Integer, String, String) -> [Integer, String, String]
Object#foo :: (Integer, String, Symbol) -> [Integer, String, Symbol]
Object#foo :: (Integer, Symbol, Integer) -> [Integer, Symbol, Integer]
Object#foo :: (Integer, Symbol, String) -> [Integer, Symbol, String]
Object#foo :: (Integer, Symbol, Symbol) -> [Integer, Symbol, Symbol]
Object#foo :: (String, Integer, Integer) -> [String, Integer, Integer]
Object#foo :: (String, Integer, String) -> [String, Integer, String]
Object#foo :: (String, Integer, Symbol) -> [String, Integer, Symbol]
Object#foo :: (String, String, Integer) -> [String, String, Integer]
Object#foo :: (String, String, String) -> [String, String, String]
Object#foo :: (String, String, Symbol) -> [String, String, Symbol]
Object#foo :: (String, Symbol, Integer) -> [String, Symbol, Integer]
Object#foo :: (String, Symbol, String) -> [String, Symbol, String]
Object#foo :: (String, Symbol, Symbol) -> [String, Symbol, Symbol]
Object#foo :: (Symbol, Integer, Integer) -> [Symbol, Integer, Integer]
Object#foo :: (Symbol, Integer, String) -> [Symbol, Integer, String]
Object#foo :: (Symbol, Integer, Symbol) -> [Symbol, Integer, Symbol]
Object#foo :: (Symbol, String, Integer) -> [Symbol, String, Integer]
Object#foo :: (Symbol, String, String) -> [Symbol, String, String]
Object#foo :: (Symbol, String, Symbol) -> [Symbol, String, Symbol]
Object#foo :: (Symbol, Symbol, Integer) -> [Symbol, Symbol, Integer]
Object#foo :: (Symbol, Symbol, String) -> [Symbol, Symbol, String]
Object#foo :: (Symbol, Symbol, Symbol) -> [Symbol, Symbol, Symbol]