def foo
  a = [[42]]
  a[0][0] = "str"
  a
end

def bar(a)
  a[0][0] = "str"
  a
end

def log(a)
end

foo
a = [[42]]
bar(a)
# limitation: a is kept as [[Integer]]
log(a)

__END__
Object#foo :: () -> [[String]]
Object#bar :: ([[Integer]]) -> [[String]]
Object#log :: ([[Integer]]) -> NilClass
