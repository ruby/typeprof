# update
def bar(n)
  :b
end

def foo(n)
  begin
    n = "str"
    1.0
  rescue StandardError
    :a
  rescue Exception
    ## TODO: bar should accept "Integer | String" ???
    bar(n)
  end
end

foo(1)

# assert
class Object
  def bar: (String) -> :b
  def foo: (Integer) -> (:a | :b | Float)
end