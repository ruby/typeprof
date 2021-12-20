class Foo
  def foo
    @name
  end
end

__END__
# Classes
class Foo
# attr_reader name: String
  def foo: -> String
end
