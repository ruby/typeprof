## update: test0.rb
class A
  class B
  end
end

class X
  class C < A
    class D < B
    end
  end
end

## assert: test0.rb
class A
  class A::B
  end
end
class X
  class X::C < A
    class X::C::D < A::B
    end
  end
end

## update: test1.rb
class X
  class A
    class B
    end
  end
end

## assert: test0.rb
class A
  class A::B
  end
end
class X
  class X::C < X::A
    class X::C::D < X::A::B
    end
  end
end
