## update
module M
  def hello = :module
end

class C
  prepend M

  def hello = :class
end

def test = C.new.hello

## assert
module M
  def hello: -> :module
end
class C
  prepend M
  def hello: -> :class
end
class Object
  def test: -> :module
end

## update
module M
  def hello = :module
end

class C
  prepend M
end

def test = C.new.hello

## assert
module M
  def hello: -> :module
end
class C
  prepend M
end
class Object
  def test: -> :module
end
