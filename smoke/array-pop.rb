def foo
  [1, "str", :sym].pop()
end

foo

__END__
# Classes
class Object
  foo : () -> (:sym | Integer | String)
end