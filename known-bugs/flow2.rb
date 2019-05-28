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