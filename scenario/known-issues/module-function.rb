## update
module M
  def foo = "foo"
  def bar = "bar"
  module_function :foo
end

C.foo

## assert
module M
  def self.foo: -> String
  def bar: -> String
  private
  def foo: -> String
end

## update
module M
  def foo = "foo"
  def bar = "bar"
  module_function :foo, :bar
end

C.foo
C.bar

## assert
module M
  def self.foo: -> String
  def self.bar: -> String
  private
  def foo: -> String
  def bar: -> String
end

## update
module M
  module_function

  def foo = "foo"
  def bar = "bar"
end

C.foo
C.bar

## assert
module M
  def self.foo: -> String
  def self.bar: -> String
  private
  def foo: -> String
  def bar: -> String
end
