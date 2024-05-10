## update: test.rb
def foo = "symbol#{ 42 }"

## assert: test.rb
class Object
  def foo: -> String
end

## update: test.rb
def foo = :"symbol#{ 42 }"

## assert: test.rb
class Object
  def foo: -> Symbol
end