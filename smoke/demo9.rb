F = -> x { "str" }

def foo(&blk)
  blk.call(:sym, &F)
end

foo do |dummy, &blk|
  blk.call(42)
end

__END__
# Classes
class Object
  F : ^(Integer) -> String
  def foo : { (:sym) { (Integer) -> String } -> String } -> String
end
