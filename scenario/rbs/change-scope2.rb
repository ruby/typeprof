# update: test0.rbs
class D
end
class C
  CONST: D
end

# update: test.rb
def test
  C::CONST
end

# assert: test.rb
class Object
  def test: -> D
end

# update: test1.rbs
class C
  class D
  end
end

# assert: test.rb
class Object
  def test: -> C::D
end