## update: test.rbs
class Object
  def required_positional_args: (Integer) -> Integer

  def optional_positional_args: (?Integer) -> Integer

  def post_required_positional_args: (?Integer, Integer) -> Integer

  def rest_positional_args: (*Integer) -> Integer

  def rest_post_positional_args: (*Integer, Integer) -> Integer

  def required_keywords: (a: Integer) -> Integer

  def optional_keywords: (?a: Integer) -> Integer

  def rest_keywords: (**untyped) -> Integer
end

## update: test.rb
required_positional_args
optional_positional_args
post_required_positional_args
rest_positional_args
rest_post_positional_args
required_keywords
optional_keywords
rest_keywords

## hover: test.rb:1:1
Object#required_positional_args : (Integer) -> Integer

## hover: test.rb:2:1
Object#optional_positional_args : (?Integer) -> Integer

## hover: test.rb:3:1
Object#post_required_positional_args : (?Integer, Integer) -> Integer

## hover: test.rb:4:1
Object#rest_positional_args : (*Integer) -> Integer

## hover: test.rb:5:1
Object#rest_post_positional_args : (*Integer, Integer) -> Integer

## hover: test.rb:6:1
Object#required_keywords : (a: Integer) -> Integer

## hover: test.rb:7:1
Object#optional_keywords : (?a: Integer) -> Integer

## hover: test.rb:8:1
Object#rest_keywords : (**untyped) -> Integer
