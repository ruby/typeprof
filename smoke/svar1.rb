def foo
  "str" =~ /(str)/
  [$&, $1]
end

foo

__END__
# Classes
class Object
  def foo : () -> ([NilClass | String, NilClass | String])
end
