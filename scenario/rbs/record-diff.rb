## update: test.rb
#: ({ name: String, age: Integer }) -> void
def accept_user(user)
  name = user[:name]
  age = user[:age]
end

## update: test.rb
#: ({ name: String, age: Integer }) -> void
def accept_user(user)
  name = user[:name]
  age = user[:age]
end

## assert: test.rb
class Object
  def accept_user: ({ name: String, age: Integer }) -> (Integer | Object)
end
