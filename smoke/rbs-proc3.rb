def log(foo)
  foo.get.call
end

foo = Foo.new
foo.set(1)
log(foo)

__END__
# Classes
class Object
  def log : (Foo[Integer]) -> Integer
end
