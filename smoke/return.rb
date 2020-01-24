def foo
  loop do
    return 42
  end
  nil
end

foo
__END__
# Classes
class Object
  foo : () -> (Integer | NilClass)
end
