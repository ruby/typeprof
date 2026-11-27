## update
#: (name: String, ?age: Integer) -> String
def greet(name:, age: 0)
  "#{name}: #{age}"
end

#: (**Integer) -> Integer
def total(**opts)
  1
end

## assert
class Object
  def greet: (name: String, ?age: Integer) -> String
  def total: (**Integer) -> Integer
end
