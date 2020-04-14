require "pathname"

def foo
  Pathname.new("foo")
end

foo

__END__
# Classes
class Object
  def foo : () -> Pathname
end
