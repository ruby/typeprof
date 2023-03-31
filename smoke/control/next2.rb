# update
def foo
  yield 1
  yield "str"
end

foo do |x|
  next 1 unless x.is_a?(Integer)
  x + 1
end

# diagnostics
