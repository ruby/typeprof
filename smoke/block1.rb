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
  foo : (String, &(Proc[(String) -> (Integer | String | Symbol)] & Proc[(Integer) -> (Integer | String | Symbol)] & Proc[(String | Symbol) -> (Integer | String | Symbol)])) -> (Integer | String | Symbol)
      | (Symbol, &(Proc[(String) -> (Integer | String | Symbol)] & Proc[(Integer) -> (Integer | String | Symbol)] & Proc[(String | Symbol) -> (Integer | String | Symbol)])) -> (Integer | String | Symbol)
end