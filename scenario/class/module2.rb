## update
module M1
  def foo(n)
  end
end

module M2
  include M1
end

module M3
  def bar(n)
  end
end

module M4
  include M3
  def foo(n)
    bar(n)
  end
end

class C
  include M2
  include M4
end

C.new.foo(:test)

## assert
module M1
  def foo: (:test) -> nil
end
module M2
end
module M3
  def bar: (:test) -> nil
end
module M4
  def foo: (:test) -> nil
end
class C
  include M2
  include M4
end
