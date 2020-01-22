def log1(x)
end
def log2(x)
end
def log3(x)
end

log2(1.step(5) {|n| log1(n) })
log3(1.step(5))

__END__
# Classes
class Object
  log2 : (Enumerator | Integer) -> NilClass
  log3 : (Enumerator) -> NilClass
  log1 : (Numeric) -> NilClass
end
