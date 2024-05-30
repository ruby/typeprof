## update
class A
  def foo
    @@x = :ok
    @@x
  end
end

## assert
class A
  def foo: -> :ok
end

## update
class B
  @@x = :ok

  def foo
    @@x
  end
end

## assert
class B
  def foo: -> :ok
end
