ARY = []

def foo(i, v)
  ARY[i] = v
  ARY
end

foo(1, "str")

__END__
# Classes
class Object
  ARY: Array[untyped]

  private
  def foo: (Integer i, String v) -> Array[untyped]
end
