## update
def yield_values
  yield 1, [1.0, "str"]
end

def check
  yield_values do |x, (y, z)|
    return [x, y, z]
  end
  nil
end

## assert
