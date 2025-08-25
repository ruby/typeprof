## update
class C
  def initialize(n)
    n
  end

  def foo(n)
    C
  end
end

C.new(1).foo("str")

## assert
class C
  def initialize: (Integer) -> void
  def foo: (String) -> singleton(C)
end
