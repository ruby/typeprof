## update
def foo(n)
  begin
    n = "str" if n == 1
    raise if n == "str"
    :c
  rescue SyntaxError
    bar(n)
  rescue Exception
    n = 2
    retry
    1.0
  else
    :b
  end
end

def bar(n)
  :a
end

foo(1)

## assert
class Object
  def foo: (Integer) -> (:a | :b | :c | Float)
  def bar: (Integer | String) -> :a
end
