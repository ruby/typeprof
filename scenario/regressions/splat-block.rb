## update: test.rbs
class Foo[X]
  def self.get1: -> Foo[:a]
  def self.get2: -> Foo[:b]
  def foo: [U] (U) { ([ U, Integer ]) -> void } -> void
end

## update: test.rb
def check(cond)
  a = cond ? Foo.get1 : Foo.get2
  a.foo(1) do |x, y|
  end
end
