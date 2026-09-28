## update: test.rbs
class Gen[T]
end

class D[T, U = String]
  def u: () -> U
end

interface _I[T]
  def get: () -> T
end

class Object
  def gen: () -> Gen
  def d: () -> D
  def i: () -> _I
  def accept_gen: (Gen[Integer]) -> String
  def accept_d: (D[Integer, String]) -> String
  def accept_i: (_I[Integer]) -> String
end

## update: test.rb
def test_gen = accept_gen(gen)
def test_d = accept_d(d)
def test_i = accept_i(i)
def raw_gen = gen
def raw_d = d
def raw_d_u = d.u
def raw_i = i

## assert
class Object
  def test_gen: -> String
  def test_d: -> String
  def test_i: -> String
  def raw_gen: -> Gen[untyped]
  def raw_d: -> D[untyped, String]
  def raw_d_u: -> String
  def raw_i: -> _I[untyped]
end
