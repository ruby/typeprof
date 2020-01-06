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
# Classes
class A
  @int : Integer
  @str : String
  @val : Integer | Integer | NilClass | String
  initialize : (Integer) -> (Integer | NilClass | String)
             | (NilClass) -> (Integer | NilClass | String)
             | (String) -> (Integer | NilClass | String)
end
class Object
  log : (A) -> NilClass
end