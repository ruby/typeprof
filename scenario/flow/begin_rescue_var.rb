## update
def test(cond, val)
  if cond
    begin
      val = val.to_i
    rescue
      raise "bad"
    end
  end
  val
end

test(true, "42")
test(false, "hello")

## assert
class Object
  def test: (bool, String) -> (Integer | String)
end
