## update: test.rb
class Foo
  BAR = 1

  attr_reader :bar_sym_reader, :baz_sym_reader
  attr_accessor :bar_sym_accessor, :baz_sym_accessor

  def initialize(n)
    @bar = n
  end

  def foo(n)
  end
end

Foo.new(1).foo(1.0)
Foo.new(1).bar_sym_reader
Foo.new(1).baz_sym_reader
Foo.new(1).bar_sym_accessor
Foo.new(1).baz_sym_accessor
Foo::BAR
Foo::BBAR = 1
Foo::BBAR
Foo::CCAR, Foo::DDAR = [1, 2]
Foo::CCAR
Foo::DDAR

## definition: test.rb:15:1
test.rb:(1,6)-(1,9) # Jump to Foo class

## definition: test.rb:15:5
test.rb:(7,6)-(7,16) # Jump Foo.initialize from Foo.new

## definition: test.rb:15:12
test.rb:(11,6)-(11,9) # Jump to Foo#foo

## definition: test.rb:16:12
test.rb:(4,14)-(4,29) # Jump to Foo#bar_sym_reader (first sym arg of attr_reader)

## definition: test.rb:17:12
test.rb:(4,31)-(4,46) # Jump to Foo#baz_sym_reader (second sym arg of attr_reader)

## definition: test.rb:18:12
test.rb:(5,16)-(5,33) # Jump to Foo#bar_sym_accessor (first sym arg of attr_accessor)

## definition: test.rb:19:12
test.rb:(5,35)-(5,52) # Jump to Foo#baz_sym_accessor (second sym arg of attr_accessor)

## definition: test.rb:20:5
test.rb:(2,2)-(2,5) # Jump to Foo#BAR (constant_write_node)

## definition: test.rb:22:5
test.rb:(21,0)-(21,9) # Jump to Foo#BBAR (constant_path_write_node)

## definition: test.rb:24:5
test.rb:(23,0)-(23,9) # Jump to Foo#BBAR (first arg of constant_path_target_node)

## definition: test.rb:25:5
test.rb:(23,11)-(23,20) # Jump to Foo#BBAR (second arg of constant_path_target_node)
