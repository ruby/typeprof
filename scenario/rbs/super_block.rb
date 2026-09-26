## update: test.rbs
class C
  def foo: () { (Integer) -> Integer } -> :ok
end

## update: test.rb
class D < C
  def foo
    super() { |x| "str" }
  end
end

## assert
class D < C
  def foo: -> :ok
end

## diagnostics
(3,18)-(3,23): expected: Integer; actual: String
