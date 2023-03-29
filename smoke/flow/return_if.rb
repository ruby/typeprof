# update
def foo(n)
  return unless n.is_a?(Integer)
  # n : Integer
  n.boo
end

foo(1)
foo("str")

# diagnostics
(4,4)-(4,7): undefined method: Integer#boo

# update
def foo(n)
  raise unless n.is_a?(Integer)
  # n : Integer
  n.boo
end

foo(1)
foo("str")

# diagnostics
(4,4)-(4,7): undefined method: Integer#boo