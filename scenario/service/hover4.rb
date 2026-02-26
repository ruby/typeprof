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
#^[A]
optional_positional_args
#^[B]
post_required_positional_args
#^[C]
rest_positional_args
#^[D]
rest_post_positional_args
#^[E]
required_keywords
#^[F]
optional_keywords
#^[G]
rest_keywords
#^[H]

## hover: [A]
Object#required_positional_args : (Integer) -> Integer

## hover: [B]
Object#optional_positional_args : (?Integer) -> Integer

## hover: [C]
Object#post_required_positional_args : (?Integer, Integer) -> Integer

## hover: [D]
Object#rest_positional_args : (*Integer) -> Integer

## hover: [E]
Object#rest_post_positional_args : (*Integer, Integer) -> Integer

## hover: [F]
Object#required_keywords : (a: Integer) -> Integer

## hover: [G]
Object#optional_keywords : (?a: Integer) -> Integer

## hover: [H]
Object#rest_keywords : (**untyped) -> Integer
