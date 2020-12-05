Foo = Class.new
Foo::Bar = 1
Foo.extend(Enumerable)

# XXX: should be supported better

__END__
# Classes
class Object
  Foo : Class
end
