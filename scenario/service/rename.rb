## update: test.rb
class Foo
  def initialize(n)
  end

  def foo(n)
  end
end

Foo.new(1).foo(1.0)
Foo.new(1).foo(1.0)
Foo.new(1).foo(1.0)

## rename: test.rb:5:7
test.rb:(5,6)-(5,9)
test.rb:(9,11)-(9,14)
test.rb:(10,11)-(10,14)
test.rb:(11,11)-(11,14)
