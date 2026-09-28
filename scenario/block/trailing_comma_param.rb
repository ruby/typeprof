## update
def yield_values
  yield 1, 2
end

def check
  yield_values do |x,|
    return x
  end
  nil
end

## assert
class Object
  def yield_values: { (Integer, Integer) -> bot } -> bot
  def check: -> Integer?
end
