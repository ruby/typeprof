## update: test.rb
def self_class
  self.class
end

def int_class
  1.class
end

def array_class
  [1].class
end

def hash_class
  { 1 => "str" }.class
end

def class_class
  Object.class
end

def unknown_class(x)
  x.class
end

## assert
class Object
  def self_class: -> singleton(Object)
  def int_class: -> singleton(Integer)
  def array_class: -> singleton(Array)
  def hash_class: -> singleton(Hash)
  def class_class: -> singleton(Class)
  def unknown_class: (untyped) -> untyped
end
