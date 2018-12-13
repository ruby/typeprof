def foo(x)
  yield 42
end

s = "str"
foo(1) do |x|
  s
end

__END__
Object#foo :: (Integer, &Proc[(Integer) -> String]) -> String
