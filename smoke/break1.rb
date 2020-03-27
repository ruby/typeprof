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
  foo : (&Proc[(Integer) -> bot]) -> bot
  bar : () -> String
end
