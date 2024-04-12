## update: test.rbs
class C
  def self.f1: -> self
  def self.f2: -> instance
  def self.f3: -> class
  def f4: -> self
  def f5: -> instance
  def f6: -> class
end

class D < C
end

## update: test.rb
def test1 = D.f1
def test2 = D.f2
def test3 = D.f3
def test4 = D.new.f4
def test5 = D.new.f5
def test6 = D.new.f6

## assert
class Object
  def test1: -> singleton(D)
  def test2: -> D
  def test3: -> singleton(D)
  def test4: -> D
  def test5: -> D
  def test6: -> singleton(D)
end
