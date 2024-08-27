## update: test.rbs
class Object
  def foo: (String) -> String
         | (Integer) -> Integer
  def get1: -> (String | Integer)
  def get2: -> (String | Integer | nil)
end

## update: test.rb
def check1 = foo(get1)
def check2 = foo(get2)

## diagnostics
(2,13)-(2,16): expected: (String | Integer); actual: (String | Integer)?
