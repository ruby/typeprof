## update: test.rbs
class Foo
  def foo: -> Foo
end

## update: test.rb
class Foo
  def initialize
    @foo = 1
  end

  attr_reader :foo
end

## diagnostics: test.rb
(6,2)-(6,18): expected: Foo; actual: Integer

## update: test.rbs
class Foo
  def foo: -> Foo
  def foo=: (Foo) -> Foo
end

## update: test.rb
class Foo
  def initialize
    @foo = 1
  end

  attr_accessor :foo
end

## diagnostics: test.rb
(6,2)-(6,20): expected: Foo; actual: (Foo | Integer)
