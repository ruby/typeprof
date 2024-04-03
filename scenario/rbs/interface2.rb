## update: test.rbs
interface _Foo
  def foo: (Integer) -> String
end

class MyFoo
  # Currently, TypeProf handles interfaces as a nominal type, so the following line is necessary.
  include _Foo

  def foo: (Integer) -> String
end

class Object
  def accept_foo: (_Foo) -> :ok
end

## update: test.rb
def main
  accept_foo(MyFoo.new)
end

## assert: test.rb
class Object
  def main: -> :ok
end
