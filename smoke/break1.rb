def foo
  yield 42
end

def bar
  foo do |n|
    break n.to_s
  end
end

bar

__END__
# Classes
class Object
  def foo : () { (Integer) -> bot } -> bot
  def bar : () -> String
end
