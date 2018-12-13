# override
def my_to_s(x)
  x.to_s
end

my_to_s(42)
my_to_s("str")
my_to_s(:sym)

__END__
Object#my_to_s :: (Integer) -> String
Object#my_to_s :: (String) -> String
Object#my_to_s :: (Symbol) -> String
