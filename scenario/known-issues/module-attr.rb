## update
class Foo
  attr :name

  def initialize
    @name = "foo"
  end
end

Foo.new.name

## assert
class Foo
  def name: -> String
  def initialize: -> void
end
