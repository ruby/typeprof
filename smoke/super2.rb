class Foo
  def f
    super
  end
end

Foo.new.f

__END__
smoke/super2.rb:3: [error] no superclass method: Foo#f
Foo#f :: () -> any
