class Foo
  def self.foo(a)
    a
  end

  foo([])
end

__END__
Foo.class#foo :: ([]) -> []
