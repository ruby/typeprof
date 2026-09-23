## update
def foo
  x = 1
  f = ->(a, b = "str"; c) { a.undefined_a; b.undefined_b; c.undefined_c; x.undefined_x }
  g = ->(a) do a.undefined_in_do end
  h = -> { _1.undefined_numbered }
  f
end

## diagnostics
(3,45)-(3,56): undefined method: String#undefined_b
(3,60)-(3,71): undefined method: nil#undefined_c
(3,75)-(3,86): undefined method: Integer#undefined_x

## assert
class Object
  def foo: -> Proc
end
