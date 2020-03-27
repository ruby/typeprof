module Foo
  module_function
  def foo(x)
    x
  end
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
