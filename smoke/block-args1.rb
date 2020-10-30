def f1
  yield
end
def log1(a, r, c); end
f1 do |a, *r, c|
  log1(a, r, c)
end

def f2
  yield :a
end
def log2(a, r, c); end
f2 do |a, *r, c|
  log2(a, r, c)
end

def f3
  yield :a, :b
end
def log3(a, r, c); end
f3 do |a, *r, c|
  log3(a, r, c)
end

def f4
  yield :a, :b, :c
end
def log4(a, r, c); end
f4 do |a, *r, c|
  log4(a, r, c)
end

def f5
  yield :a, :b, :c, :d
end
def log5(a, r, c); end
f5 do |a, *r, c|
  log5(a, r, c)
end

__END__
# Classes
class Object
  def f1 : { -> nil } -> nil
  def log1 : (nil, [], nil) -> nil
  def f2 : { (:a) -> nil } -> nil
  def log2 : (:a, [], nil) -> nil
  def f3 : { (:a, :b) -> nil } -> nil
  def log3 : (:a, [], :b) -> nil
  def f4 : { (:a, :b, :c) -> nil } -> nil
  def log4 : (:a, Array[:b], :c) -> nil
  def f5 : { (:a, :b, :c, :d) -> nil } -> nil
  def log5 : (:a, Array[:b | :c], :d) -> nil
end
