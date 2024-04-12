## update: test.rb
def foo(h)
  h.each do |k, v|
    return v
  end
  nil
end

foo({ a: 42 })
foo({ b: "str" })

## assert
class Object
  def foo: (Hash[:a, Integer] | Hash[:b, String]) -> (Integer | String)?
end
