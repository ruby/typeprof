## update
class A
end

class B
  def initialize(xxx) # 5
#                  ^[A]
    @xxx = xxx
  end
end

class C
end

def foo
  B.new(1) # 14
#     ^[B]
end

## assert
class A
end
class B
  def initialize: (Integer) -> void
end
class C
end
class Object
  def foo: -> B
end

## hover: [A]
Integer

## hover: [B]
B#initialize : (Integer) -> void
