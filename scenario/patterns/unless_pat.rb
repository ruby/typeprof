## update: test.rb
def cond?(x)
  x
end

def check(x)
  case x
  in 1 unless cond?(:ok)
    :ok
  end
end

## assert
class Object
  def cond?: (:ok) -> :ok
  def check: (untyped) -> :ok
end
