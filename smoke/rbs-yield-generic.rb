class Foo
  def start  # :yield: http
    yield
  end

  def passthrough(&block)
    start(&block)
  end

  def with_block
    start { "foo" }
  end
end

__END__
# Errors
smoke/rbs-yield-generic.rb:7: [error] failed to resolve overload: Foo#start

# Classes
class Foo
# def start: [T] () { () -> T } -> T
  def passthrough: -> untyped
  def with_block: -> String
end
