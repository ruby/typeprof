## update: test0.rb
class C
  define_method(:hello) { "hi" }
end

C.new.hello

## assert: test0.rb
class C
  def hello: -> String
end

## update: test0.rb
class C
end

C.new.hello

## assert: test0.rb
class C
end

## update: test0.rb
class C
  define_method(:greeting) { "hi" }
end

C.new.greeting

## assert: test0.rb
class C
  def greeting: -> String
end

## update: test0.rb
class C
  def self.define_method(x); x; end
  define_method(1)
end

## assert: test0.rb
class C
  def self.define_method: (Integer) -> Integer
end

## update: test0.rb
class C
  define_method(:hello) { "hi" }
end

C.new.hello

## assert: test0.rb
class C
  def hello: -> String
end
