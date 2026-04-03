## update
module Foo
  module_function

  def bar
    42
  end
end

Foo.bar

## assert
module Foo
  def bar: -> Integer
  def self.bar: -> Integer
end
