## update
class C
  #: -> Integer
  def foo
    return

    return "str"

    1.0
  end
end

## diagnostics
(4,4)-(4,10): expected: Integer; actual: nil
(6,4)-(6,16): expected: Integer; actual: String
(8,4)-(8,7): expected: Integer; actual: Float
