## update
class C
  def foo
    foo
    1
  end

  alias foo foo
end

## assert
class C
  def foo: -> Integer
end
