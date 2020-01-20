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
smoke/any2.rb:2: [warning] no block given
smoke/any2.rb:5: [warning] no block given
# Classes
class Object
  foo : () -> any
  bar : () -> Integer
end
