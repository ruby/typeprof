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
Object#foo :: (String, &(Proc[(String) -> String] & Proc[(Integer) -> Integer])) -> Integer
Object#foo :: (Symbol, &(Proc[(Symbol) -> (Symbol | Integer)] & Proc[(Integer) -> Integer])) -> Integer
