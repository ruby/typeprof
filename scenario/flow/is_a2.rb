## update: test0.rb
class C
end

class D
  def foo(n)
    if n.is_a?(C)
      n
    else
      "str"
    end
  end
end

D.new.foo(C.new)

## assert: test0.rb
class C
end
class D
  def foo: (C) -> (C | String)
end

## update: test1.rb
class D
  class C
  end
end

## assert: test0.rb
class C
end
class D
  def foo: (C) -> String
end

## update: test1.rb
class D
end
"
class A::C
  X = 1
end
"

## assert: test0.rb
class C
end
class D
  def foo: (C) -> (C | String)
end
