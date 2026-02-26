## update: test.rbs
class Foo
  def self.f: (Array[Integer]) -> String | (Array[String]) -> Symbol
end

## update: test.rb
# Generic type arguments in overload selection cause oscillation.
#
# typecheck_for_module (sig_type.rb) recursively checks type parameter
# vertices. When an element vertex is empty, typecheck returns true
# (via !found_any), making all overloads match. The resulting disjoint
# return types feed back and cause the element types to oscillate.
#
# Variants that exhibit the same issue:
#   - Hash[Symbol, Integer] vs Hash[Symbol, String]
#   - Array[Array[Integer]] vs Array[Array[String]]
#   - Custom generic: Box[Integer] vs Box[String]
#   - Tuple: [Integer] vs [String]
def check
  @x = Foo.f([@x])
end

## assert
class Object
  def check: -> untyped
end

## diagnostics
