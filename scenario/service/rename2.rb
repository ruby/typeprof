## update: test.rb
class Foo
#      ^[A]
end

Foo = 1

Foo
Foo + Foo

## rename: [A]
test.rb:(1,6)-(1,9)
test.rb:(6,0)-(6,3)
test.rb:(7,0)-(7,3)
test.rb:(7,6)-(7,9)
test.rb:(4,0)-(4,3)
