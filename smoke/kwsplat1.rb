def foo(k:)
end

h = { k: 42 }
foo(**h)

def bar(int:, str:)
end

if rand < 0.5
  h = { int: 42 }
else
  h = { str: "str" }
end
bar(**h)

def baz(**kw)
end

if rand < 0.5
  h = { int: 42 }
else
  h = { str: "str" }
end
baz(**h)

def qux(**kw)
end

qux(**any)

__END__
# Errors
smoke/kwsplat1.rb:30: [error] undefined method: Object#any
# Classes
class Object
  def foo : (k: Integer) -> nil
  def bar : (int: Integer, str: String) -> nil
  def baz : (**{:int=>Integer, :str=>String}) -> nil
  def qux : (**{untyped=>untyped}) -> nil
end
