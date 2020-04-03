require "pathname"

def foo
  Pathname("foo")
end

foo

__END__
# Classes
class Object
  foo : () -> Pathname
end
