def foo
  1.respond_to?(:foo)
end

foo
__END__
# Classes
class Object
  foo : () -> Boolean
end
