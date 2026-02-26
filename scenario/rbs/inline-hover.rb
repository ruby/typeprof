## update: test.rb
#: (Integer) -> void
def check(var)
#          ^[A]
  var
#  ^[B]
end

## hover: [A]
Integer

## hover: [B]
Integer

## update: test2.rb
class Foo
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
