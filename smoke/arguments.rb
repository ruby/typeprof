def foo(x)
end
def bar(x)
end

bar(foo(1, 2))

__END__
smoke/arguments.rb:6: [error] wrong number of arguments (given 2, expected 1)
Object#foo :: (Integer, Integer) -> NilClass
Object#bar :: (any) -> NilClass
Object#bar :: (NilClass) -> NilClass
