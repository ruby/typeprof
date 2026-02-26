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
#^[A]^[B]   ^[C]
Foo.new(1).bar_sym_reader
#           ^[D]
Foo.new(1).baz_sym_reader
#           ^[E]
Foo.new(1).bar_sym_accessor
#           ^[F]
Foo.new(1).baz_sym_accessor
#           ^[G]
Foo::BAR
#    ^[H]
Foo::BBAR = 1
Foo::BBAR
#    ^[I]
Foo::CCAR, Foo::DDAR = [1, 2]
Foo::CCAR
#    ^[J]
Foo::DDAR
#    ^[K]

## definition: [A]
test.rb:(1,6)-(1,9) # Jump to Foo class

## definition: [B]
test.rb:(7,6)-(7,16) # Jump Foo.initialize from Foo.new

## definition: [C]
test.rb:(11,6)-(11,9) # Jump to Foo#foo

## definition: [D]
test.rb:(4,14)-(4,29) # Jump to Foo#bar_sym_reader (first sym arg of attr_reader)

## definition: [E]
test.rb:(4,31)-(4,46) # Jump to Foo#baz_sym_reader (second sym arg of attr_reader)

## definition: [F]
test.rb:(5,16)-(5,33) # Jump to Foo#bar_sym_accessor (first sym arg of attr_accessor)

## definition: [G]
test.rb:(5,35)-(5,52) # Jump to Foo#baz_sym_accessor (second sym arg of attr_accessor)

## definition: [H]
test.rb:(2,2)-(2,5) # Jump to Foo#BAR (constant_write_node)

## definition: [I]
test.rb:(21,0)-(21,9) # Jump to Foo#BBAR (constant_path_write_node)

## definition: [J]
test.rb:(23,0)-(23,9) # Jump to Foo#CCAR (first arg of constant_path_target_node)

## definition: [K]
test.rb:(23,11)-(23,20) # Jump to Foo#DDAR (second arg of constant_path_target_node)
