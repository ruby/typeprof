## update
def grouping
  (1 + 2)
end

def nested
  ((3))
end

def empty
  ()
end

def with_default(x = ())
  x
end

grouping
nested
empty
with_default
with_default(1)

## assert
class Object
  def grouping: -> Integer
  def nested: -> Integer
  def empty: -> nil
  def with_default: (?Integer?) -> Integer?
end
