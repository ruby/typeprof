## update
def foo = { "@context": "x", "data-id": 1 }

## assert
class Object
  def foo: -> { :@context => String, :"data-id" => Integer }
end
