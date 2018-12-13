class A
  def initialize(x)
    @int = 1
    @str = "str"
    @val = x
  end
end

def log(x)
end
log A.new(1)
A.new("str")
A.new(nil)

__END__
A#@int :: Integer
A#@str :: String
A#@val :: Integer | String | NilClass
A#initialize :: (Integer) -> Integer
A#initialize :: (String) -> String
A#initialize :: (NilClass) -> NilClass
Object#log :: (A) -> NilClass
