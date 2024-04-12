## update: test0.rb
class C
  def foo
    bar(1) # should call all subclass methods
  end
end

class D < C
end

## update: test1.rb

class D < C
  def bar(n)
  end
end

## assert
class D < C
  def bar: (Integer) -> nil
end
