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
  else
    check_else(x)
    x = :e
  ensure
    x = :f
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
  def check_after: (:a | :c | :d | :e | :f) -> nil
end
