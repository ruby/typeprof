## update
class C
  class << self
    attr_accessor :age
  end
end

C.age = 1
C.age

## assert
class C
  def self.age: -> Integer
  def self.age=: (Integer) -> Integer
end

## update
class C
  class << self
    attr_reader :name
    attr_writer :value
  end
end

C.value = "value"

## assert
class C
  def self.name: -> untyped
  def self.value=: (String) -> String
end
