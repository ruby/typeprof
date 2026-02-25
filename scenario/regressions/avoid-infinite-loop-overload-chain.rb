## update: test.rbs
class Foo
  def self.transform: (Integer) -> String
                    | (String) -> Float
                    | (Float) -> Symbol
end

## update: test.rb
def check
  @x = Foo.transform(@x)
end

## diagnostics: test.rb

## assert
class Object
  def check: -> untyped
end
