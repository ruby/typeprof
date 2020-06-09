def foo(&blk)
  [blk]
end

foo { }
foo { }

__END__
# Classes
class Object
  def foo : () -> ([Proc[] | Proc[]])
end
