def no_argument
  "str"
end

def one_argument(x)
end

no_argument
one_argument(1)

__END__
# Classes
class Object
  no_argument : () -> String
  one_argument : (Integer) -> NilClass
end
