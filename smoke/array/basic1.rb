# update: test0.rb
def foo(a)
  a
end

# update: test1.rb
foo([1, 2, 3].to_a)

# assert: test0.rb
def foo: (Array[Integer]) -> Array[Integer]

# update: test1.rb
foo([1, 2, 3].to_a)
foo(["str"].to_a)

# assert: test0.rb
def foo: (Array[Integer] | Array[String]) -> (Array[Integer] | Array[String])

# update: test1.rb
foo(["str"].to_a)

# assert: test0.rb
def foo: (Array[String]) -> Array[String]