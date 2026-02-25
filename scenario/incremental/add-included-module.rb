## update: test0.rb
module M
end

def foo
  M::A.new(1)
end
## update: test0.rb
module M
end

def foo
  M::A.new(1)
end

## update: test1.rb
module M
  class A
    def initialize(n)
    end
  end
end

## update: test1.rb
module M
  class A
    def initialize(n)
    end
  end
end

## assert: test1.rb
module M
  class A
    def initialize: (Integer) -> void
  end
end
