## update: test.rb
#: () -> Integer
def foo
  "string"
end

foo
#\
^[A]

## hover: [A]
Object#foo : -> Integer

## diagnostics
(3,2)-(3,10): expected: Integer; actual: String

## update: test.rb
#: () -> Integer?
def foo
  "string"
end

foo
#\
^[B]

## hover: [B]
Object#foo : -> Integer?

## update: test.rb
#: () -> (Integer | String)?
def foo
  "string"
end

foo
#\
^[C]

# TODO: The above test is mainly for SIG_TYPE#show

## hover: [C]
Object#foo : -> (Integer | String)?
