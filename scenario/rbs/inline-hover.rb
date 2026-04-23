## update: test.rb
class Foo
  #: (Integer) -> void
  def check(var)
#            ^[A]
    var
#    ^[B]
  end
end

## hover: [A]
Integer

## hover: [B]
Integer

## update: test2.rb
class Foo2
  #: (String) -> void
  def bar(x)
#         ^[C]
    x
#   ^[D]
  end
end

## hover: [C]
String

## hover: [D]
String
