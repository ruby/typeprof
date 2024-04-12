## update: test.rbs
class Foo
  include Enumerable[Integer]
end

## update: test.rb
def foo
  Foo.new.map {|x| return x; :a }
end

## assert: test.rb
class Object
  def foo: -> (Array[:a] | Integer)
end
