## update: model.rb
class Foo
  def value = 1
end

module Bar
  class Foo < Foo
  end
end

## update: test.rb
def call
  Bar::Foo.new.value
end

## assert: test.rb
class Object
  def call: -> Integer
end
