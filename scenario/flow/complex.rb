## update
def accept_int_or_str(x) = nil
def accept_float_or_str(x) = nil
def accept_str(x) = nil
def accept_any(x) = nil

def foo(x)
  if accept_any(x) && x.is_a?(String) && accept_str(x) || x.is_a?(Float)
    accept_float_or_str(x)
  else
    accept_int_or_str(x)
  end
end

foo(1)
foo(1.0)
foo("")

## assert
class Object
  def accept_int_or_str: (Integer | String) -> nil
  def accept_float_or_str: (Float | String) -> nil
  def accept_str: (String) -> nil
  def accept_any: (Float | Integer | String) -> nil
  def foo: (Float | Integer | String) -> nil
end
