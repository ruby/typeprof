def foo(x); end

foo(Integer(1))
foo(Integer("str"))

__END__
Object#foo :: (Integer) -> NilClass
