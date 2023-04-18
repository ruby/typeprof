## update: test.rb
class Foo
  def initialize(n)
  end

  def foo(n)
  end
end

Foo.new(1).foo(1.0)

## definition: test.rb:9:1
test.rb:(1,0)-(7,3)

## definition: test.rb:9:5
test.rb:(2,2)-(3,5)

## definition: test.rb:9:12
test.rb:(5,2)-(6,5)
