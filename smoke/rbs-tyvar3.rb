class StringFoo
  def initialize
    @foo = Foo.new
  end

  def set
    @foo.set("42")
  end

  def get
    @foo.get
  end
end

StringFoo.new.set
StringFoo.new.get

__END__
# Classes
class StringFoo
  @foo : Foo[String] | Foo[bot]
  def initialize : -> Foo[bot]
  def set : -> void
  def get : -> String
end
