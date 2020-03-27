module Foo
  def foo(x)
    x
  end
  module_function :foo
end

class Bar
  include Foo
  def bar
    foo(:y)
  end
end

Foo.foo(:x)
Bar.new.bar

__END__
# Classes
class Bar
  include Foo
  bar : () -> (:x | :y)
end
module Foo
  foo : (:x | :y) -> (:x | :y)
end
