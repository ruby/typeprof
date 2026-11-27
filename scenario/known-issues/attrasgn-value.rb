## update
class C
  def foo=(x)
    :ret
  end

  def []=(k, v)
    :ret
  end
end

def check_attrasgn
  c = C.new
  c.foo = 1
end

def check_index_asgn
  c = C.new
  c[:a] = 1
end

## assert
class C
  def foo=: (Integer) -> :ret
  def []=: (:a, Integer) -> :ret
end
class Object
  def check_attrasgn: -> Integer
  def check_index_asgn: -> Integer
end
