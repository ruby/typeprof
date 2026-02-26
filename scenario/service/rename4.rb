## update: test.rb
Foo = 1
#^[B]
Foo
#^[A]

## rename: [A]
test.rb:(1,0)-(1,3)
test.rb:(2,0)-(2,3)

## rename: [B]
test.rb:(1,0)-(1,3)
test.rb:(2,0)-(2,3)

## hover: [B]
Integer
