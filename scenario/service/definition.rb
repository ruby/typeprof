## update: test.rb
class Foo
  BAR = 1

  attr_reader :bar, :baz

  def initialize(n)
    @bar = n
  end

  def foo(n)
  end
end

Foo.new(1).foo(1.0)
Foo.new(1).bar
Foo.new(1).baz
Foo::BAR
Foo::BBAR = 1
Foo::BBAR
Foo::CCAR, Foo::DDAR = [1, 2]
Foo::CCAR
Foo::DDAR

## definition: test.rb:14:1
test.rb:(1,6)-(1,9) # Jump to Foo class

## definition: test.rb:14:5
test.rb:(6,6)-(6,16) # Jump Foo.initialize from Foo.new

## definition: test.rb:14:12
test.rb:(10,6)-(10,9) # Jump to Foo#foo

## definition: test.rb:15:12
test.rb:(4,2)-(4,24) # Jump to Foo#bar (first arg of attr_reader)

## definition: test.rb:16:12
test.rb:(4,2)-(4,24) # Jump to Foo#baz (second arg of attr_reader)

## definition: test.rb:17:5
test.rb:(2,2)-(2,5) # Jump to Foo#BAR (constant_write_node)

## definition: test.rb:19:5
test.rb:(18,0)-(18,9) # Jump to Foo#BBAR (constant_path_write_node)

## definition: test.rb:21:5
test.rb:(20,0)-(20,9) # Jump to Foo#BBAR (first arg of constant_path_target_node)

## definition: test.rb:22:5
test.rb:(20,11)-(20,20) # Jump to Foo#BBAR (second arg of constant_path_target_node)
