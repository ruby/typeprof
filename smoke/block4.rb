def foo
  yield "str"
end

def bar
  yield :sym
end

blk = -> x { x }
foo(&blk)
bar(&blk)

__END__
# Classes
class Object
  def foo : { (String) -> (:sym | String) } -> (:sym | String)
  def bar : { (:sym) -> (:sym | String) } -> (:sym | String)
end
