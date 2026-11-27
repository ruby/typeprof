## update
Foo = Struct.new(:bar?)
Foo.new(true)

## assert
class Foo
  def bar?: -> true
  def `bar?=`: (untyped) -> untyped
  def initialize: (?true) -> void
  def self.[]: (?true) -> Foo
end
