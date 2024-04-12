## update
class C
  def foo(n)
    C
  end
end

## assert
class C
  def foo: (untyped) -> singleton(C)
end

## update
class C
  class C
  end

  def foo(n)
    C
  end
end

## assert
class C
  class C::C
  end
  def foo: (untyped) -> singleton(C::C)
end

## update
class C
  class D
  end

  def foo(n)
    C
  end
end

## assert
class C
  class C::D
  end
  def foo: (untyped) -> singleton(C)
end
