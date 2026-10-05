## update: test.rb
def foo(flag)
  [1].each do
    while flag
      break :b
    end
  end
end

## assert: test.rb
class Object
  def foo: (untyped) -> Array[Integer]
end
