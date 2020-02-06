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
  foo : () -> {:int=>Integer, :str=>String}
  bar : () -> ({Integer=>Integer | String, String=>String})
end
