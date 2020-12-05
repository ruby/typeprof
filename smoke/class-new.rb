Foo = Class.new
Foo::Bar = 1

# XXX: should be supported better

__END__
# Classes
class Object
  Foo : Class
end
