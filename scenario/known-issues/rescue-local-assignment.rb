## update
def foo
  x = :start
  begin
    1
  rescue
    x = :rescue
  end
  x
end

## assert
class Object
  def foo: -> (:rescue | :start)
end

## update
def foo
  x = :start
  begin
    1
  rescue
    x = :rescue
  else
    x = :else
  end
  x
end

## assert
class Object
  def foo: -> (:else | :rescue)
end

## update
def foo
  e = :before
  begin
    1
  rescue ArgumentError => e
    2
  end
  e
end

## assert
class Object
  def foo: -> (:before | ArgumentError)
end
