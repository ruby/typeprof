## update
def foo(n)
  found = nil
  while n < 3
    n += 1
    if n == 1
      found = "a"
      next
    end
  end
  found
end

foo(0)

## assert
class Object
  def foo: (Integer) -> String?
end

## update
def foo
  found = nil
  [1, 2].each do |item|
    if item == 1
      found = :hit
      next
    end
  end
  found
end

## assert
class Object
  def foo: -> :hit?
end
