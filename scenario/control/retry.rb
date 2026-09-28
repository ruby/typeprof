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

def baz
  n = 1
  begin
    raise if rand < 0.5
    n
  rescue
    n = "str"
    retry
  end
end

def qux
  n = 1
  begin
    raise if rand < 0.5
    n
  rescue
    n = "str"
    begin
      retry
    end
  end
end

foo(1)
baz
qux

## assert
class Object
  def foo: (Integer) -> (:a | :b | :c | Float)
  def bar: (Integer | String) -> :a
  def baz: -> (Integer | String)
  def qux: -> (Integer | String)
end
