## update
class C
  def target = C::C
end

## assert
class C
  def target: -> untyped
end