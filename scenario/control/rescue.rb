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
    ## TODO: bar should accept "Integer | String" ???
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
  def bar: (String) -> :c
  def foo: (Integer) -> (:a | :b | :c | :d | Float)
  def baz: (Integer) -> (:a | Integer)
end
