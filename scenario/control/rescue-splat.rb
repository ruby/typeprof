## update
def foo
  begin
    :a
  rescue *[StandardError]
    :b
  end
end

foo

## assert
class Object
  def foo: -> (:a | :b)
end
