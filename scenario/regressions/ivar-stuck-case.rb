## update: test.rbs
class Foo
  def check: [T] (T) -> [T]
end

## update: test.rb
class Foo
  def foo
    @foo = []
    @foo = check(@foo)
  end
end
