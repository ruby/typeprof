## update
class Foo
  @@count = 0

  def increment
    @@count += 1
    @@count
  end
end

## assert
class Foo
  def increment: -> Integer
end
