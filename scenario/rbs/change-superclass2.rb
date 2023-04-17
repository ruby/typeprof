## update: test.rbs
class A
end
class B < A
end
class C < B
end
class D < C
end

## update: test1.rbs
class Object
  def accept_a: (A) -> :a
  def accept_b: (B) -> :b
  def accept_c: (C) -> :c
  def accept_d: (D) -> :d
end

## update: test.rb

def test_a_a = accept_a(A.new)
def test_a_b = accept_a(B.new)
def test_a_c = accept_a(C.new)
def test_a_d = accept_a(D.new)

def test_b_a = accept_b(A.new)
def test_b_b = accept_b(B.new)
def test_b_c = accept_b(C.new)
def test_b_d = accept_b(D.new)

def test_c_a = accept_c(A.new)
def test_c_b = accept_c(B.new)
def test_c_c = accept_c(C.new)
def test_c_d = accept_c(D.new)

def test_d_a = accept_d(A.new)
def test_d_b = accept_d(B.new)
def test_d_c = accept_d(C.new)
def test_d_d = accept_d(D.new)

## assert: test.rb
class Object
  def test_a_a: -> :a
  def test_a_b: -> :a
  def test_a_c: -> :a
  def test_a_d: -> :a
  def test_b_a: -> untyped
  def test_b_b: -> :b
  def test_b_c: -> :b
  def test_b_d: -> :b
  def test_c_a: -> untyped
  def test_c_b: -> untyped
  def test_c_c: -> :c
  def test_c_d: -> :c
  def test_d_a: -> untyped
  def test_d_b: -> untyped
  def test_d_c: -> untyped
  def test_d_d: -> :d
end

## update: test.rbs
class A
end
class B < A
end
class C
end
class C2 < B
end
class D < C2
end

## assert: test.rb
class Object
  def test_a_a: -> :a
  def test_a_b: -> :a
  def test_a_c: -> untyped
  def test_a_d: -> :a
  def test_b_a: -> untyped
  def test_b_b: -> :b
  def test_b_c: -> untyped
  def test_b_d: -> :b
  def test_c_a: -> untyped
  def test_c_b: -> untyped
  def test_c_c: -> :c
  def test_c_d: -> untyped
  def test_d_a: -> untyped
  def test_d_b: -> untyped
  def test_d_c: -> untyped
  def test_d_d: -> :d
end