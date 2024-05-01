## update: test0.rb
#: { () -> Integer } -> void
def foo
  yield
end

foo do
  next

  next "str"

  1.0
end

## diagnostics: test0.rb
(11,2)-(11,5): expected: Integer; actual: Float
(7,2)-(7,6): expected: Integer; actual: nil
(9,2)-(9,12): expected: Integer; actual: String
