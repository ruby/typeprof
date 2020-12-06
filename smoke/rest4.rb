def foo(*a)
end

a = ["str"] + ["str"]
foo(1, *a, :s)

def bar(x, y, z)
end

a = ["str"] + ["str"]
bar(1, *a, :s)

__END__
# Classes
class Object
  private
  def foo: (*:s | Integer | String) -> nil
  def bar: (Integer, :s | String, :s | String) -> nil
end
