ARY = []

def foo(i, v)
  ARY[i] = v
  ARY
end

foo(1, "str")

__END__
# Classes
class Object
  def foo : (Integer, String) -> []
end
