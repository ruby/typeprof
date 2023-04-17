## update: test0.rb
class C
  def target(n) = n
end
class C2
  def target(n) = n
end

class X
  class D < C
    # This invokes C#target
    def foo = target(1)
  end
end

## assert: test0.rb
class C
  def target: (Integer) -> Integer
end
class C2
  def target: (untyped) -> untyped
end
class X
  class X::D < C
    def foo: -> Integer
  end
end

## update: test1.rb
class X
  # This class definition changes the superclass of D, and
  # also changes the call to "target" will invoke C2#target
  class C < C2
  end
end

## assert: test0.rb
class C
  def target: (untyped) -> untyped
end
class C2
  def target: (Integer) -> Integer
end
class X
  class X::D < X::C
    def foo: -> Integer
  end
end
