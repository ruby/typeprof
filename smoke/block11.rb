def log1(x)
end
def log2(x)
end

def foo
  x = nil
  1.times do |_|
    x = 1
    log1(x)
  end
  x
end

def test_yield
  yield
end

def bar
  x = nil
  test_yield do
    x = 1
    log2(x)
  end
  x
end

foo
bar

__END__
Object#foo :: () -> (NilClass | Integer)
Object#log1 :: (NilClass) -> NilClass
Object#log1 :: (Integer) -> NilClass
Object#bar :: () -> (NilClass | Integer)
Object#test_yield :: (&Proc[() -> NilClass]) -> NilClass
Object#log2 :: (NilClass) -> NilClass
Object#log2 :: (Integer) -> NilClass