def foo(x)
  yield x
  yield 1
end

foo("str") do |x|
  x
end

foo(:sym) do |x|
  if 1+1
    x
  else
    1
  end
end

__END__
# Classes
class Object
  foo : (:sym | String, &(Proc[(String) -> (:sym | Integer | String)] & Proc[(Integer) -> (:sym | Integer | String)] & Proc[(:sym | String) -> (:sym | Integer | String)])) -> (:sym | Integer | String)
end
