## update
module M
  def bar = :BAR
end
class P
  def baz = :BAZ
end
class C < P
  include M
  def foo = :FOO
end
x = C.new
x

## completion: test.rb:12:0
C#foo : -> :FOO
M#bar : -> :BAR
P#baz : -> :BAZ
