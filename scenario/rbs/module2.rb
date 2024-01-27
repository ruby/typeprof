## update: test.rbs
module M
end

class Object
  def accept_m: (M) -> String
end

## update: test.rb
class C
  include M
end

def test
  accept_m(C.new)
end

## assert
class C
  include M
end
class Object
  def test: -> String
end
