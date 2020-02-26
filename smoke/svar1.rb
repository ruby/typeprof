def foo
  "str" =~ /(str)/
  [$&, $1]
end

foo

__END__
# Classes
class Object
  foo : () -> ([NilClass | String, NilClass | String])
end
