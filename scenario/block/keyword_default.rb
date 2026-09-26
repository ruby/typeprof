## update
def helper(a, b) = a

# The default value of a block keyword is analyzed as a lambda's is
def foo = [1].each { |x: helper(1)| x }
foo

## diagnostics
(4,25)-(4,31): wrong number of arguments (1 for 2)

## assert
class Object
  def helper: (untyped, untyped) -> untyped
  def foo: -> Array[Integer]
end

## update
def helper(a, b) = a

def foo = [1].each { |x: helper(1, 2)| x }
foo

## diagnostics

## assert
class Object
  def helper: (Integer, Integer) -> Integer
  def foo: -> Array[Integer]
end
