## update
# A lambda passed as a block binds like a method, as it does for #call
def rest = [1, 2].map(&->(*a) { a })
rest

def post = [1, 2].map(&->(*a, b) { b })
post

def too_many = [1, 2].map(&->(x, y) { y })
too_many

## diagnostics
(8,22)-(8,25): wrong number of arguments (1 for 2)

## assert
class Object
  def rest: -> Array[Array[Integer]]
  def post: -> Array[Integer]
  def too_many: -> Array[untyped]
end
