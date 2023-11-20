## update: test.rb
#: () -> Integer
def foo
  "string"
end

foo

## hover: test.rb:6:0
Object#foo : -> ::Integer

## diagnostics
(3,2)-(3,10): expected: Integer; actual: String

## update: test.rb
#: () -> Integer?
def foo
  "string"
end

foo

## hover: test.rb:6:0
Object#foo : -> ::Integer?

## update: test.rb
#: () -> (Integer | String)?
def foo
  "string"
end

foo

# TODO: The above test is mainly for SIG_TYPE#show

## hover: test.rb:6:0
Object#foo : -> (::Integer | ::String)?
