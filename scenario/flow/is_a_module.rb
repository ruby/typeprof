## update
module M
  def m_method = :MMM
end

class C
  include M
  def c_method = :CCC
end

class D
  def d_method = :DDD
end

def foo(x)
  if x.is_a?(M)
    [x.m_method, x.c_method]
  else
    x.d_method
  end
end

foo(C.new)
foo(D.new)

## diagnostics
## assert
module M
  def m_method: -> :MMM
end
class C
  include M
  def c_method: -> :CCC
end
class D
  def d_method: -> :DDD
end
class Object
  def foo: (C | D) -> (:DDD | [:MMM, :CCC])
end
