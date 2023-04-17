## update
module M
  def foo
    42
  end
end

class C
  include M
  def bar
    foo
  end
end

## assert
module M
  def foo: -> Integer
end
class C
  include M
  def bar: -> Integer
end