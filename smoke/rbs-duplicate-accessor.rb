class Foo
  attr_reader :a
  attr_writer :b
  attr_accessor :c

  attr_reader :d
  attr_writer :e
  attr_accessor :f
end
__END__
# Classes
class Foo
# attr_reader a: String
# attr_writer b: String
# attr_accessor c: String
  attr_reader d: untyped
  attr_writer e: untyped
  attr_accessor f: untyped
end
