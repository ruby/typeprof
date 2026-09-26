## update
def rest = ->(*x) { x }.call(1, "str")
rest

def lead_and_rest = ->(x, *y) { y }.call(1, 2, 3)
lead_and_rest

def post = ->(x, *y, z) { z }.call(1, 2, :sym)
post

def keywords = ->(k: 1) { k }.call(k: "str")
keywords

def keyword_from_keyword = ->(k:, j: k) { j }.call(k: 1)
keyword_from_keyword

def rest_keywords = ->(**kw) { kw }.call(a: 1)
rest_keywords

def block_param = ->(&b) { b }.call

def block_given = ->(&b) { b }.call { 1 }
block_given

## assert
class Object
  def rest: -> Array[Integer | String]
  def lead_and_rest: -> Array[Integer]
  def post: -> :sym
  def keywords: -> (Integer | String)
  def keyword_from_keyword: -> Integer
  def rest_keywords: -> { a: Integer }
  def block_param: -> untyped
  def block_given: -> Proc
end
