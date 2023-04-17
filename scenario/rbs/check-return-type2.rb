## update: test0.rb
class Bar
end

class Foo
  #: -> Bar
  def foo
    ::Bar.new
  end
end

## update: test1.rb
class Foo
  class Bar
  end
end

## diagnostics: test0.rb
(7,4)-(7,13): expected: Foo::Bar; actual: Bar