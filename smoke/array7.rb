def foo
  a = [1]
  a[1] = "str"
  a
end

foo

__END__
Object#foo :: () -> Array[Integer | String]
