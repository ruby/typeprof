def foo
  "str" =~ /(str)/
  [$&, $1]
end

foo

__END__
smoke/svar1.rb:2: [error] undefined method: String#=~
Object#foo :: () -> [String | NilClass, String | NilClass]
