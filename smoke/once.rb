def foo
  r = /foo#{x=1}bar/o
  [r, x]
end

foo

__END__
# Classes
class Object
  def foo : -> [Regexp, Integer?]
end
