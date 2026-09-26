## update
# With no keyword parameters, keywords are passed as a trailing hash
def one_hash = ->(h) { h }.call(k: 1)
one_hash

def trailing_hash = ->(a, b) { b }.call(1, k: 2)
trailing_hash

## diagnostics

## assert
class Object
  def one_hash: -> { k: Integer }
  def trailing_hash: -> { k: Integer }
end
