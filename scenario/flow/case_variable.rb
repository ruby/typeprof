## update
def test(type, val)
  case type
  when :int
    val = val.to_i
  when :sym
    val = val.to_sym
  else
    val = val
  end
  val
end

test(:int, "42")
test(:sym, "hello")

## assert
class Object
  def test: (:int | :sym, String) -> (Integer | String | Symbol)
end
