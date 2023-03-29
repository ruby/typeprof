# update
class C
  def foo
    @x
  end
end

# assert
class C
  def foo: -> untyped
end