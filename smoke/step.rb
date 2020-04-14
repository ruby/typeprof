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
  def log1 : (Integer | Numeric) -> NilClass
  def log2 : (any) -> NilClass
  def log3 : (Enumerator) -> NilClass
end
