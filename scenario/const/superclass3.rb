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
  class B
  end
end
class X
  class C < A
    class D < A::B
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
  class B
  end
end
class X
  class C < X::A
    class D < X::A::B
    end
  end
end
