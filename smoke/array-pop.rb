def foo
  [1, "str", :sym].pop()
end

foo

__END__
# Classes
class Object
  def foo : -> (:sym | Integer | String)
end
