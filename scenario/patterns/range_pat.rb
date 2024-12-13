## update: test.rb
def check(x)
  case x
  in (0..)
    :ok1
  in -1
    :ok2
  end
end

## assert
class Object
  def check: (untyped) -> (:ok1 | :ok2)
end
