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
# Classes
class Common
  func : (:sym | String, &(Proc[(Integer) -> Integer] & Proc[(Integer) -> :sym2])) -> (:sym2 | Integer)
end
class Foo
  foo : () -> (:sym2 | Integer)
end
class Bar
  bar : () -> (:sym2 | Integer)
end
