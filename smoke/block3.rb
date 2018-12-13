class Common
  def func(x)
    yield 1
  end
end

class Foo
  def foo
    Common.new.func("str") do |x|
      1
    end
  end
end

class Bar
  def bar
    Common.new.func(:sym) do |x|
      :sym2
    end
  end
end

Foo.new.foo
Bar.new.bar

__END__
Foo#foo :: () -> Integer
Common#func :: (String, &Proc[(Integer) -> Integer]) -> Integer
Common#func :: (Symbol, &Proc[(Integer) -> Symbol]) -> Symbol
Bar#bar :: () -> Symbol
