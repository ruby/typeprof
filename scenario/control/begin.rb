## update
def foo
  begin
    1
  rescue
    "str"
  end
end

## assert
class Object
  def foo: -> (Integer | String)?
end

## update
def foo
  begin
    1
  ensure
    "str"
  end
end

## assert
class Object
  def foo: -> Integer?
end


## update
def foo
  begin
    1
  rescue
    "str"
  else
    true
  end
end

## assert
class Object
  def foo: -> (Integer | String | true)
end
