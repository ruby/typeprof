## update
class Foo
  class Bar
    Baz = 1
  end
end

p Foo::Bar::Baz
#  ^[A] ^[B]^[C]

## rename: [A]
test.rb:(1,6)-(1,9)
test.rb:(7,2)-(7,5)

## rename: [B]
test.rb:(2,8)-(2,11)
test.rb:(7,7)-(7,10)

## rename: [C]
test.rb:(3,4)-(3,7)
test.rb:(7,12)-(7,15)
