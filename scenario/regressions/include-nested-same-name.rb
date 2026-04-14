# Regression: when a module contains a same-name nested class,
# RBS `include` resolution used to oscillate between the module
# and the nested class, causing define_all to loop forever.

## update: test.rbs
module M
  class M
  end

  def foo: () -> String
end

class C
  include M
end

## update: test.rb
def test
  C.new.foo
end

## assert
class Object
  def test: -> String
end
