## update
def too_few = ->(x, y) { x }.call(1)
too_few

def too_many = ->(x) { x }.call(1, 2)
too_many

# an array is one argument to a lambda, not a list to spread over its parameters
def no_autosplat = ->(x, y) { x }.call([1, "str"])
no_autosplat

def optional_ok = ->(x, y = 2) { y }.call(1)
optional_ok

## diagnostics
(1,29)-(1,33): wrong number of arguments (1 for 2)
(4,27)-(4,31): wrong number of arguments (2 for 1)
(8,34)-(8,38): wrong number of arguments (1 for 2)

## assert
class Object
  def too_few: -> untyped
  def too_many: -> untyped
  def no_autosplat: -> untyped
  def optional_ok: -> Integer
end
