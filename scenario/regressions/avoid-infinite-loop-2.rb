## update: test.rbs
class Foo
  def foo: -> Foo?
  def self.bar: (Foo) -> Foo
end

## update: test.rb
def check
  # The old infinite-loop scenario
  #  1. both @a and @b are untyped
  #  2. @b is now Foo because `@b = Foo.bar(@a)` and `Foo.bar: (Foo) -> Foo` and @a is untyped
  #  3. @a is now Foo? because of `@a = @b.foo` and @b is Foo
  #  4. @b is now untyped because `@b = Foo.bar(@a)` and `Foo.bar: (Foo) -> Foo` and @a is Foo | nil
  #  5. go to 2
  #
  # How did I fixed:
  #  `Foo.bar: (Foo) -> Foo` should match against `Foo | nil`
  #  (TODO: add a diagnostics for this)
  @a = @b.foo
  @b = Foo.bar(@a)
end

def check2
  @a = @b[0]
  @b = '/' + @a
end
