def foo
  { int: 1, str: "str" }
end

foo

def bar
  { 1 => 1, 2 => "str", "s" => "s" }
end

bar

__END__
# Classes
class Object
  def foo : -> {int: Integer, str: String}
  def bar : -> ({Integer=>Integer | String, String=>String})
end
