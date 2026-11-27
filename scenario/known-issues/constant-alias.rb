## update
module M
  CONST = 1
end

Alias = M

def test = Alias::CONST

## assert
module M
  CONST: Integer
end
Alias: singleton(M)
class Object
  def test: -> Integer
end

## update
class Base
  def hello = :hi
end

Alias = Base

class Foo < Alias
end

def test = Foo.new.hello

## assert
class Base
  def hello: -> :hi
end
Alias: singleton(Base)
class Foo < Base
end
class Object
  def test: -> :hi
end
