## update: test.rb
class Foo
  def initialize(n)
#      ^[A]
  end

  def foo(n)
#      ^[B]
  end
end

Foo.new(1).foo(1.0)
Foo.new(1).foo(1.0)
Foo.new(1).foo(1.0)

## references: [A]
test.rb:(9,0)-(9,10)
test.rb:(10,0)-(10,10)
test.rb:(11,0)-(11,10)

## references: [B]
test.rb:(9,0)-(9,19)
test.rb:(10,0)-(10,19)
test.rb:(11,0)-(11,19)
