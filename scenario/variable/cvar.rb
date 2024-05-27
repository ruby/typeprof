## update
class A
  @@x = :ok

  def foo
    @@x
  end
end

## assert
class A
  def foo: -> :ok
end
