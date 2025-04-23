## update
def foo
  begin
    :a
  rescue
    :b
  rescue SyntaxError
    :c
  rescue Exception
    :d
  else
    :e
  end
end

def bar(n)
  n rescue :a
end

foo
bar(1)

## assert
class Object
  def foo: -> (:a | :b | :c | :d | :e)
  def bar: (Integer) -> (:a | Integer)
end
