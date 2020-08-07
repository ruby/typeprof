def log1(x)
end

def log2(x)
end

class A
  FOO=1
  @@var = 1
  log1(@@var)
  def foo
    log2(@@var)
  end
end

A.new.foo

__END__
# Classes
class Object
  def log1 : (Integer) -> nil
  def log2 : (Integer) -> nil
end
class A
  @@var : Integer
  def foo : () -> nil
end
