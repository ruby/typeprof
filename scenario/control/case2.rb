## update
def accept_int(x) = nil
def accept_str(x) = nil
def accept_sym(x) = nil
def foo(x)
  case x
  when Integer
    accept_int(x)
  when String
    accept_str(x)
  when Array
    accept_str(x.join)
  else
    accept_sym(x)
  end
end

foo(1)
foo("foo")
foo([1])
foo(:bar)

## assert
class Object
  def accept_int: (Integer) -> nil
  def accept_str: (String) -> nil
  def accept_sym: (:bar) -> nil
  def foo: (:bar | Integer | String | [Integer]) -> nil
end
