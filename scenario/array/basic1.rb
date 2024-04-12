## update: test0.rb
def foo(a)
  a
end

## update: test1.rb
foo([1, 2, 3].to_a)

## assert: test0.rb
class Object
  def foo: (Array[Integer]) -> Array[Integer]
end

## update: test1.rb
foo([1, 2, 3].to_a)
foo(["str"].to_a)

## assert: test0.rb
class Object
  def foo: (Array[Integer] | Array[String]) -> (Array[Integer] | Array[String])
end

## update: test1.rb
foo(["str"].to_a)

## assert: test0.rb
class Object
  def foo: (Array[String]) -> Array[String]
end
