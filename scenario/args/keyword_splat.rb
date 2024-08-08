## update
def foo(check: false)
end

opt = { foo: 1 }
foo(**opt) # I am not sure what is the best here, but tentatively...

## assert
class Object
  def foo: (?check: Integer | false) -> nil
end
