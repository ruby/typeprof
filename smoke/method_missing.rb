class D
  def foo(x, y, z)
  end
end

class C
  def initialize(x)
    @target = x
  end

  def method_missing(m, *args)
    @target.send(m, *args)
  end
end

C.new(D.new).foo(:X, :Y, :Z)

__END__
# Classes
class D
  def foo: (:X, :Y, :Z) -> nil
end

class C
  @target: D
  def initialize: (D) -> D
  def method_missing: (:foo, *:X | :Y | :Z) -> nil
end
