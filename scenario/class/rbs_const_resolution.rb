## update: test.rbs
module Outer
  class Base
    include Inner
  end

  module Inner
    def foo: -> Integer
  end
end

## update: test.rb
class Inner < Outer::Base
  def bar
    foo
  end
end

## assert: test.rb
class Inner < Outer::Base
  def bar: -> Integer
end
