def foo(*)
end

__END__
# Classes
class Object
  private
  def foo: (*untyped noname) -> nil
end
