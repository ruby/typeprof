def foo(n)
  if n.is_a?(Integer)
    n + 1
  else
    n + "STR"
  end
end

foo(42)
foo("str")

__END__
Object#foo :: (Integer) -> Integer
Object#foo :: (String) -> String
