## update: test.rb
class Foo::Bar
  class C
    def foo
      1
    end
  end
end

# Currently, Foo::Bar::C cannot be resolved because there is no definition of Foo
class D < Foo::Bar::C
  def check = foo
end

## assert: test.rb
class Foo::Bar
  class C
    def foo: -> Integer
  end
end
class D # failed to identify its superclass
  def check: -> untyped
end

## update: test.rbs
module Foo
end

## assert: test.rb
class Foo::Bar
  class C
    def foo: -> Integer
  end
end
class D < Foo::Bar::C
  def check: -> Integer
end
