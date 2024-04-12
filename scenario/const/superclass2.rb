## update: test0.rb
class A
  class B
  end
end

class X
  class C < A::B
  end
end

## assert: test0.rb
class A
  class A::B
  end
end
class X
  class X::C < A::B
  end
end

## update: test1.rb
class X
  class A
    # This affects the superclass of X::C
  end
end

## assert: test0.rb
class A
  class A::B
  end
end
class X
  class X::C # failed to identify its superclass
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
  class X::C < X::A::B
  end
end
