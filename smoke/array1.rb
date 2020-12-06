def foo(a)
  a[0]
end
def bar(n); end
def baz(n); end
def qux(n); end
def quux(n); end

a = [42, "str"]
foo(a)
bar(a[0])
n = 1
baz(a[n])
qux(a[2])
n = 0+0
quux(a[n])

__END__
# Classes
class Object
  private
  def foo: ([Integer, String]) -> Integer
  def bar: (Integer) -> nil
  def baz: (String) -> nil
  def qux: (nil) -> nil
  def quux: (Integer | String) -> nil
end
