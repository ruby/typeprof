def foo
  while 1+1
    a = [1]
  end
  a
end

foo

__END__
# Classes
class Object
  def foo : () -> [Integer]?
end
