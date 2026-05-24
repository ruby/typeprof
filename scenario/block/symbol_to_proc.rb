## update: test.rbs
class Receiver
  def render: (Integer) -> String
  def render_kw: (key: Integer) -> Float
end

class Object
  def yield_receiver: [R] { (Receiver, Integer) -> R } -> R
end

## update: test.rb
def map_to_i
  ["1", "2"].map(&:to_i)
end

def yield_to_symbol_proc
  yield_receiver(&:render)
end

def apply_to(value)
  yield value
end

def yield_from_ruby_method
  apply_to("1", &:to_i)
end

def apply_to_kw(value)
  yield value, key: 1
end

def yield_from_ruby_method_kw
  apply_to_kw(Receiver.new, &:render_kw)
end

## assert: test.rb
class Object
  def map_to_i: -> Array[Integer]
  def yield_to_symbol_proc: -> String
  def apply_to: (String) { (String) -> Integer } -> Integer
  def yield_from_ruby_method: -> Integer
  def apply_to_kw: (Receiver) { (Receiver) -> Float } -> Float
  def yield_from_ruby_method_kw: -> Float
end
