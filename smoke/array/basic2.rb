# update: test0.rb
def bar(a)
  [a].to_a
end

# update: test1.rb
bar(1)

# assert: test0.rb
class Object
  def bar: (Integer) -> Array[Integer]
end

# update: test1.rb
bar(1)
bar("str")

# assert: test0.rb
class Object
  def bar: (Integer | String) -> Array[Integer | String]
end

# update: test1.rb
bar("str")

# assert: test0.rb
class Object
  def bar: (String) -> Array[String]
end
