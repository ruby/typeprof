# update: test.rbs
class Object
  def foo: (Integer) -> Integer
         | (String) -> String
end

# update: test.rb
foo(1)
foo("1")
foo(1.0)

# diagnostics: test.rb
(3,0)-(3,3): failed to resolve overloads