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
class A
  @@var : Integer
  foo : () -> NilClass
end
class Object
  log1 : (Integer) -> NilClass
  log2 : (Integer) -> NilClass
end
