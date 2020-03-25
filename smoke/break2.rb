# TODO: it should return a string

def foo
  1.times do |n|
    raise
  rescue
    break "str"
  end
end

foo

__END__
# Classes
class Object
  foo : () -> Integer
end
