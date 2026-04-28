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

def in_array
  [()]
end

def in_condition
  if (); 1; end
end

def take_arg(x); x; end

def empty_as_arg
  take_arg(())
end

def empty_as_splat_arg
  take_arg(*())
end

def empty_as_kw_splat
  { **() }
end

grouping
nested
empty
with_default
with_default(1)
in_array
in_condition
empty_as_arg
empty_as_splat_arg
empty_as_kw_splat

## assert
class Object
  def grouping: -> Integer
  def nested: -> Integer
  def empty: -> nil
  def with_default: (?Integer?) -> Integer?
  def in_array: -> [nil]
  def in_condition: -> Integer?
  def take_arg: (nil) -> nil
  def empty_as_arg: -> nil
  def empty_as_splat_arg: -> nil
  def empty_as_kw_splat: -> Hash[untyped, untyped]
end
