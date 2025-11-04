## update: test.rbs
class Foo
  def check: () -> Integer
end

class Bar < Foo
  def check: ...
end

## update: test.rb
def check
  Bar.new.check
end

## assert
class Object
  def check: -> Integer
end
