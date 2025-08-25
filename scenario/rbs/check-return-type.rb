## update
#: -> Integer
def foo
  return

  return "str"

  1.0
end

## diagnostics
(3,2)-(3,8): expected: Integer; actual: nil
(5,2)-(5,14): expected: Integer; actual: String
(7,2)-(7,5): expected: Integer; actual: Float
