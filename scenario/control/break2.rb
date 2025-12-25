## update
def foo
  count = 0
  loop do
    count += 1
    break count if count == 3
  end
end

## assert
class Object
  def foo: -> Integer
end

## update
def foo
  count = 0
  loop do
    count += 1
    begin
      break count if count == 3
    rescue
      break count
    end
  end
end

## assert
class Object
  def foo: -> Integer
end

## update
def foo
  count = 0
  loop do
    count += 1
    begin
      break count if count == 3
    rescue
      break 'str'
    end
  end
end

## assert
class Object
  def foo: -> (Integer | String)
end

## update
def foo
  count = 0
  loop do
    count += 1
    begin
      # break count if count == 3
    rescue
      break 'str'
    end
  end
end

## assert
class Object
  def foo: -> String
end
