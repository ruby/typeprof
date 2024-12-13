## update: test.rb
def check(x)
  case x
  in 1 | 2
    :ok
  in 3 | 4 | 5
    :ok
  end
end

## assert
class Object
  def check: (untyped) -> :ok
end
