def f1
  yield
end
def log1(a, o, r, c); end
f1 do |a, o=:opt, *r, c|
  log1(a, o, r, c)
end

def f2
  yield :a
end
def log2(a, o, r, c); end
f2 do |a, o=:opt, *r, c|
  log2(a, o, r, c)
end

def f3
  yield :a, :b
end
def log3(a, o, r, c); end
f3 do |a, o=:opt, *r, c|
  log3(a, o, r, c)
end

def f4
  yield :a, :b, :c
end
def log4(a, o, r, c); end
f4 do |a, o=:opt, *r, c|
  log4(a, o, r, c)
end

def f5
  yield :a, :b, :c, :d
end
def log5(a, o, r, c); end
f5 do |a, o=:opt, *r, c|
  log5(a, o, r, c)
end

def f6
  yield :a, :b, :c, :d, :e
end
def log6(a, o, r, c); end
f6 do |a, o=:opt, *r, c|
  log6(a, o, r, c)
end

__END__
# Classes
class Object
  def f1 : { -> nil } -> nil
  def log1 : (nil, :opt, [], nil) -> nil
  def f2 : { (:a) -> nil } -> nil
  def log2 : (:a, :opt, [], nil) -> nil
  def f3 : { (:a, :b) -> nil } -> nil
  def log3 : (:a, :b | :opt, [], :b) -> nil
  def f4 : { (:a, :b, :c) -> nil } -> nil
  def log4 : (:a, :b | :opt, [], :c) -> nil
  def f5 : { (:a, :b, :c, :d) -> nil } -> nil
  def log5 : (:a, :b | :opt, Array[:c], :d) -> nil
  def f6 : { (:a, :b, :c, :d, :e) -> nil } -> nil
  def log6 : (:a, :b | :opt, Array[:c | :d], :e) -> nil
end
