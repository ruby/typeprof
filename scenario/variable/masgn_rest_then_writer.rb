## update: test.rb
class C
  def []=(i, v)
    @v = v
  end

  def x=(v)
    @x = v
  end
end

def check(c)
  *a, c[0], c.x = 1, 2, "str", :sym
  a
end

def check_nested(c)
  *a, (c[0], c.x) = 1, 2, ["str", :sym]
  a
end

check(C.new)
check_nested(C.new)

## assert
class C
  def []=: (Integer, String) -> String
  def x=: (:sym) -> :sym
end
class Object
  def check: (C) -> Array[Integer]
  def check_nested: (C) -> Array[Integer]
end
