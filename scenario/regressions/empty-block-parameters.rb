## update
def call_block(&b)
  b.call
end

call_block { || 42 }

call_block { |; x| x = 42; x }

## assert
class Object
  def call_block: { () -> Integer } -> Integer
end
