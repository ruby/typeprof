## update
Dog = Struct.new(:name, :age)
Dog.new("fred", 5)

## assert
class Dog
  def name: -> String
  def name=: (untyped) -> untyped
  def age: -> Integer
  def age=: (untyped) -> untyped
  def initialize: (String, Integer) -> void
  def self.[]: (String, Integer) -> Dog
end

## update
Dog = Struct.new(:name, :age) do
  def initialize(name, age)
    super(name.to_s, age.to_i)
  end
end
Dog.new("fred", "5")

## assert
class Dog
  def name: -> String
  def name=: (untyped) -> untyped
  def age: -> Integer
  def age=: (untyped) -> untyped
  def self.[]: (String, Integer) -> Dog
  def initialize: (String, String) -> void
end

## update
Dog = Struct.new(:name, :age)
Dog.new("fred", 5)

## assert
class Dog
  def name: -> String
  def name=: (untyped) -> untyped
  def age: -> Integer
  def age=: (untyped) -> untyped
  def initialize: (String, Integer) -> void
  def self.[]: (String, Integer) -> Dog
end
