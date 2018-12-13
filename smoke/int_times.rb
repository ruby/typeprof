def foo(n)
  z = "str"
  n.times {|i| z = i }
  # TODO: n.times { z = 42 }
  z
end

foo(42)

__END__
Object#foo :: (Integer) -> (Integer | String)
