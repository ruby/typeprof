# update: test0.rb
module M
  def foo(n)
  end
end

class C
  include M
end

C.new.foo(1)

# assert: test0.rb
module M
  def foo: (Integer) -> nil
end
class C
end

# update: test1.rb
class C
  module M
    def foo(n)
    end
  end
end

# assert: test0.rb
module M
  def foo: (untyped) -> nil
end
class C
end

# assert: test1.rb
class C
  module C::M
    def foo: (Integer) -> nil
  end
end