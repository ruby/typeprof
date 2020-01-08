class Foo
  def initialize
    @ary = [1, "str", :sym]
  end

  def foo
    @ary[1]
  end

  def bar
    @ary[1] = nil
  end
end

Foo.new.foo # bug...
Foo.new.bar

__END__
# Classes
class Foo
  @ary : [Integer, String, :sym]
  initialize : () -> [Integer, String, :sym]
  foo : () -> String
  bar : () -> NilClass
end