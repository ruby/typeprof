## update
class C
  def bar(n)
  end

  def test
    alias foo bar # This alias is reused
    foo(1)
  end
end

## update
class C
  def bar(n)
  end

  def test
    alias foo bar # This alias is reused
    foo(1)
  end
end

## update
class C
  def bar(n)
  end

  def test
    # The alias was removed
    foo(1)
  end
end

## assert
class C
  def bar: (untyped) -> nil
  def test: -> untyped
end