## update
def foo
  x = :a
  begin
    x = :b
    raise
    x = :c
  rescue
    check_rescue(x)
    x = :d
  # ensure # TODO: Looks like commenting out these two lines makes the test fail? Need to fix
  #   x = :f
  else
    check_else(x)
    x = :e
  end
  check_after(x)
end

def check_rescue(n) = nil
def check_else(n) = nil
def check_after(n) = nil

## assert
class Object
  def foo: -> nil
  def check_rescue: (:a | :c) -> nil
  def check_else: (:c) -> nil
  def check_after: (:a | :c | :d | :e) -> nil
end
