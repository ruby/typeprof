def foo(n = 1)
end

foo("str")

__END__
# Classes
class Object
  def foo : (?Integer | String) -> nil
end
