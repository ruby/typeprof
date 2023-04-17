# update
def foo
  a = [[nil]]
  while a
    a = a[0] # 4
  end
  a
end

def bar
  a = [[nil]]
  until a
    a = a[0] # 12
  end
  a
end

def baz
  a = [[nil]]
  begin a
    a = a[0] # 20
  end while a
  a
end

# assert
class Object
  def foo: -> ([[nil]] | [nil])?
  def bar: -> ([[nil]] | [nil])?
  def baz: -> ([[nil]] | [nil])?
end

# diagnostics
(4,8)-(4,12): undefined method: nil#[]
(12,8)-(12,12): undefined method: nil#[]
(20,8)-(20,12): undefined method: nil#[]