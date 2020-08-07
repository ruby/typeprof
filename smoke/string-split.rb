def foo
  "".split("").map {|n| n.to_i }
end

foo

__END__
# Classes
class Object
  def foo : -> Array[Integer]
end
