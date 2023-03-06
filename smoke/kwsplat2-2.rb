# RUBY_VERSION >= 3.3

def foo(*r, k:)
end

a = [1, 2, 3]
h = { k: 42 }
foo(*a, **h)

__END__
# Classes
class Object
  private
  def foo: (*Integer r, k: Integer) -> nil
end
