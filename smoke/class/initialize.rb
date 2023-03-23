# update
class A
end

class B
  def initialize(xxx)
    @xxx = xxx
  end
end

class C
end

def foo
  B.new(1)
end

# assert
class A
end
class B
  def initialize: (Integer) -> Integer
end
class C
end
class Object
  def foo: -> B
end

# hover: (5, 19)
Integer