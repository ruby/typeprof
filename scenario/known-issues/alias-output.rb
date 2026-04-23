## update
class C
  def hello = "hi"
  alias greet hello
end

C.new.greet

## assert
class C
  def hello: -> String
  alias greet hello
end

## update
class C
  def hello = "hi"
  alias_method :greet, :hello
end

C.new.greet

## assert
class C
  def hello: -> String
  alias greet hello
end
