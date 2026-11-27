## update: test.rbs
class Object
  def foo: (String) -> Integer
         | (String, exception: bool) -> String
end

## update: test.rb
def check = foo("str")

## assert: test.rb
class Object
  def check: -> Integer
end
