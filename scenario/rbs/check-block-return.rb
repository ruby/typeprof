## update: test0.rb
class C
  #: { () -> Integer } -> void
  def foo
    yield
  end

  def test
    foo do
      next

      next "str"

      1.0
    end
  end
end

## diagnostics: test0.rb
(9,6)-(9,10): expected: Integer; actual: nil
(11,6)-(11,16): expected: Integer; actual: String
(13,6)-(13,9): expected: Integer; actual: Float
