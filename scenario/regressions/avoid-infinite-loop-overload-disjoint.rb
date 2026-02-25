## update: test.rbs
class Foo
  def self.transform: (Integer) -> Float
                    | (String) -> Symbol
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
