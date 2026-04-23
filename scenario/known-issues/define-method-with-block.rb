## update
class C
  define_method(:hello) { "hi" }
  define_method(:double) {|x| x * 2 }
end

C.new.hello
C.new.double(1)

## assert
class C
  def hello: -> String
  def double: (Integer) -> Integer
end
