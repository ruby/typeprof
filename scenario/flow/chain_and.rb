## update
def accept_str(x) = nil
def accept_any(x) = nil

def foo(x)
  accept_any(x) && x.is_a?(String) && accept_str(x)
end

foo(1)
foo("")

## assert
class Object
  def accept_str: (String) -> nil
  def accept_any: (Integer | String) -> nil
  def foo: (Integer | String) -> bool?
end

## update
def accept_str(x) = nil

def foo(x)
  x && accept_str(x)
end

foo(nil)
foo("")

## assert
class Object
  def accept_str: (String) -> nil
  def foo: (String?) -> String?
end
