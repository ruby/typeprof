def no_argument
  "str"
end

def one_argument(x)
end

no_argument
one_argument(1)

__END__
Object#no_argument :: () -> String
Object#one_argument :: (Integer) -> NilClass
