# update: test.rbs
class C
  def foo: (singleton(C)) -> :ok
end

# update: test.rb
C = 1
class Foo
  def foo
    C
  end
end

# assert: test.rb
C: Integer
class Foo
  def foo: -> (Integer | singleton(C))
end

# update: test.rbs
## class C is removed

# assert: test.rb
C: Integer
class Foo
  def foo: -> Integer
end