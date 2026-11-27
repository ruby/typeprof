## update: test.rbs
class C
  def foo: () -> Integer
         | (Hash[Symbol, Integer]) -> String
  def bar: (Hash[Symbol, Integer]) -> String
end

## update: test.rb
def check1 = C.new.foo(a: 1)
def check2 = C.new.bar(a: 1)
def check3 = { a: 1 }.merge(b: "str")
def check4 = "abc".sub(/a/, "a" => "X")

## assert: test.rb
class Object
  def check1: -> String
  def check2: -> String
  def check3: -> Hash[:a | :b, Integer | String]
  def check4: -> String
end

## diagnostics: test.rb
