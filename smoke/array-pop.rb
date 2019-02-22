def foo
  [1, "str", :sym].pop()
end

foo

__END__
Object#foo :: () -> (Symbol | String | Integer)
