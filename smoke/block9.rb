def foo(&b)
  b = 1
  b
end

foo { }

__END__
Object#foo :: () -> Integer
