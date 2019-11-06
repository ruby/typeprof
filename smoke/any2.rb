def foo
  yield
end
def bar
  yield
  1
end

foo
bar

__END__
# Errors
smoke/any2.rb:2: [error] no block given
smoke/any2.rb:5: [error] no block given
# Classes
class Object
  foo : () -> any
  bar : () -> Integer
end
