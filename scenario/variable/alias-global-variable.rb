## update
def foo
  $v = :ok
end

def bar
  alias $new_v $v
  $new_v
end

## assert
class Object
  def foo: -> :ok
  def bar: -> :ok
end

## update
def foo
  $v = :ok
end

def bar
  alias $new_v $v
  $new_v = 1
end

def baz
  $v
end

## assert
class Object
  def foo: -> :ok
  def bar: -> Integer
  def baz: -> (:ok | Integer)
end

## update
def foo
  $v = :ok
end

def bar
  $new_v
end

## assert
class Object
  def foo: -> :ok
  def bar: -> untyped
end
