def foo
  "str" =~ /(str)/
  [$&, $1]
end

foo

__END__
# Errors
smoke/svar1.rb:2: [error] undefined method: String#=~
# Classes
class Object
  foo : () -> ([NilClass | String, NilClass | String])
end
