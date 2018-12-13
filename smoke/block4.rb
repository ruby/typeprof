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
Object#foo :: (&Proc[(String) -> String]) -> String
Object#bar :: (&Proc[(Symbol) -> Symbol]) -> Symbol
