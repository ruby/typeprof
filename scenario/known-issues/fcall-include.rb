## update
class C
  def include(x)
    x
  end

  def check
    include(1)
  end
end

## assert
class C
  def include: (Integer) -> Integer
  def check: -> Integer
end
