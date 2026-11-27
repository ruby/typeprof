## update
class C
  def check = take(*gen)
  def gen = [1, "str"]
  def take(a, b) = a
end

## assert
class C
  def check: -> (Integer | String)
  def gen: -> [Integer, String]
  def take: (Integer | String, Integer | String) -> (Integer | String)
end
