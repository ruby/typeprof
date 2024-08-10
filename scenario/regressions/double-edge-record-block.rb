## update
def foo(&blk)
  obj = [1]
  obj.each(&blk)
  obj.each(&blk)
end

foo {|x, y|}
