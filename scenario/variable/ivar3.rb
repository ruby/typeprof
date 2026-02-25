## update: test0.rb
class C
  def foo = (@x = :C)
  def x = @x
end

class X
  class D < C
  end
end

class E < X::D
  def foo = (@x = :E)
end

## assert: test0.rb
class C
  def foo: -> :C
  def x: -> (:C | :E)
end
class X
  class D < C
  end
end
class E < X::D
  def foo: -> :E
end

## update: test1.rb
class X
  class C
    def foo = (@x = :XC)
    def x = @x
  end
end

## assert: test0.rb
class C
  def foo: -> :C
  def x: -> :C
end
class X
  class D < X::C
  end
end
class E < X::D
  def foo: -> :E
end

## assert: test1.rb
class X
  class C
    def foo: -> :XC
    def x: -> (:E | :XC)
  end
end
