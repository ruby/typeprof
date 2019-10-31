def log1(x)
end
def log2(x)
end
def log3(x)
end

log2(1.step(5) {|n| log1(n) })
log3(1.step(5))

__END__
Object#log1 :: (Numeric) -> NilClass
Object#log2 :: (Numeric) -> NilClass
Object#log3 :: (Enumerator) -> NilClass
