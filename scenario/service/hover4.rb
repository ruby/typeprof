## update: test.rbs
class Object
  def required_positional_args: (Integer) -> Integer

  def optional_positional_args: (?Integer) -> Integer

  def post_required_positional_args: (?Integer, Integer) -> Integer

  def rest_positional_args: (*Integer) -> Integer
end

## update: test.rb
required_positional_args
optional_positional_args
post_required_positional_args
rest_positional_args

## hover: test.rb:1:1
Object#required_positional_args : (::Integer) -> ::Integer

## hover: test.rb:2:1
Object#optional_positional_args : (?::Integer) -> ::Integer

## hover: test.rb:3:1
Object#post_required_positional_args : (?::Integer, ::Integer) -> ::Integer

## hover: test.rb:4:1
Object#rest_positional_args : (*::Integer) -> ::Integer
