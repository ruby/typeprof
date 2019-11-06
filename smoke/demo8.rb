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
  foo : (&Proc[(String) -> String]) -> String
  bar : (&Proc[(Symbol) -> Symbol]) -> Symbol
end
