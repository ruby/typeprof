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

## update
class C
  def foo
    foo
    42
  end
  alias foo bar
  alias bar foo
end

## assert
class C
  def foo: -> Integer
end

## update
class C
  def bar
    foo
    42
  end
  alias foo bar
  alias bar foo
end

## assert
class C
  def bar: -> Integer
end

## update
class C
  alias foo bar
  alias bar foo
end

C.new.foo

## assert
class C
end
