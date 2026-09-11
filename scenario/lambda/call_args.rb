## update
def rest = ->(*x) { x }.call(1, "str")
rest

def lead_and_rest = ->(x, *y) { y }.call(1, 2, 3)
lead_and_rest

def post = ->(x, *y, z) { z }.call(1, 2, :sym)
post

def keywords = ->(k: 1) { k }.call(k: "str")
keywords

def rest_keywords = ->(**kw) { kw }.call(a: 1)
rest_keywords

def block_param = ->(&b) { b }.call

## assert
class Object
  def rest: -> Array[Integer | String]
  def lead_and_rest: -> Array[Integer]
  def post: -> :sym
  def keywords: -> (Integer | String)
  def rest_keywords: -> { a: Integer }
  def block_param: -> untyped
end
