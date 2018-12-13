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
Foo#@ary :: [Integer, String, Symbol]
Foo#initialize :: () -> [Integer, String, Symbol]
Foo#foo :: () -> String
Foo#bar :: () -> NilClass
