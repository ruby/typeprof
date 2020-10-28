def foo(&blk)
  $blk = blk
  nil
end

foo {|n| }

$blk.call(42)

__END__
# Global variables
$blk : ^(Integer) -> nil

# Classes
class Object
  def foo : { (Integer) -> nil } -> nil
end
