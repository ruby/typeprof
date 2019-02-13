def foo
  a = [[nil]]
  a[0] = a
  a
end

foo

__END__
Object#foo :: () -> [any]
