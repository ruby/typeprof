class Foo
  def self.foo?
    !!@foo
  end

  def self.bar?
    !!@bar
  end

  def foo?
    self.class.foo?
  end

  def bar?
    self.class.bar?
  end
end
__END__
# Classes
class Foo
  self.@foo: bot
  self.@bar: bot

# def self.foo?: -> bool
# def foo?: -> bool
  def self.bar?: -> bool
  def bar?: -> bool
end
