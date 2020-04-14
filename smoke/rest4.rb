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
  def foo : (*:s | Integer | String) -> NilClass
  def bar : (Integer, :s | String, :s | String) -> NilClass
end
