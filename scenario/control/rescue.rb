## update
def bar(n)
  :c
end

def foo(n)
  begin
    n = "str"
    1.0
  rescue
    :a
  rescue SyntaxError
    :b
  rescue Exception
    bar(n)
  else
    :d
  end
end

def baz(n)
  n rescue :a
end

foo(1)
baz(1)

## assert
class Object
  def bar: (Integer | String) -> :c
  def foo: (Integer) -> (:a | :b | :c | :d | Float)
  def baz: (Integer) -> (:a | Integer)
end
