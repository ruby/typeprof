## update
def foo(a, b, c, o1 = :default)
  o1
end

ary = ["str"].to_a
foo(:A, :B, :C, *ary)

## assert
class Object
  def foo: (:A, :B, :C, ?:default | String) -> (:default | String)
end
