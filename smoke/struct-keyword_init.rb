# XXX: Need to support keyword_init
Foo = Struct.new(:foo, keyword_init: true)

class Foo
  def initialize(foo:)
    super(foo: foo.to_s)
  end
end

Foo.new(42)

__END__
# Errors
smoke/struct-keyword_init.rb:10: [error] wrong number of arguments (given 1, expected 0)

# Classes
class Foo < Struct
  attr_accessor foo(): nil
  def initialize: (foo: untyped) -> Foo
end
