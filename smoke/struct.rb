# tentative
class Foo < Struct.new(:a)
end
Foo.new.a = 1
__END__
# Classes
class (Struct) < Struct
  attr_accessor a() : untyped
end

class Foo < (Struct)
end
