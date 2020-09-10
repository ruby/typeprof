def foo(n)
  case n
  when Integer
    n + 1
  when String
    n + "STR"
  else
    n
  end
end

foo(42)
foo("str")
foo(:sym)

__END__
# Errors
smoke/flow7.rb:4: [error] failed to resolve overload: String#+
smoke/flow7.rb:4: [error] undefined method: :sym#+
smoke/flow7.rb:6: [error] failed to resolve overload: Integer#+
smoke/flow7.rb:6: [error] undefined method: :sym#+

# Classes
class Object
  def foo : (:sym | Integer | String) -> (:sym | Integer | String | untyped)
end
