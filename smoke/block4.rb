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
  foo : (&Proc[(String) -> (String | Symbol)]) -> (String | Symbol)
  bar : (&Proc[(Symbol) -> (String | Symbol)]) -> (String | Symbol)
end