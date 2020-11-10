def foo
  case [:a, :b, :c]
  in [a, b, :c]
    return a, b
  end
end

foo

__END__
# Classes
class Object
  def foo : -> [:a?, :b?]
end
