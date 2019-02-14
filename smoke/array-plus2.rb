class Foo
  def foo
    @var = [1]
    @var = @var + [2]
  end
end

Foo.new.foo

__END__
Foo#@var :: [Integer] | Array[Integer]
Foo#foo :: () -> Array[Integer]
