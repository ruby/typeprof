## update
def accept_int_or_str(x) = nil
def accept_sym(x) = nil
def foo(x)
  case x
  when Integer, String
    accept_int_or_str(x)
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
  def accept_int_or_str: (Integer | String) -> nil
  def accept_sym: (:bar) -> nil
  def foo: (:bar | Integer | String | [Integer]) -> nil
end
