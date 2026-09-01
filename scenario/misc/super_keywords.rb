## update
class B
  def foo(a, b: 1) = [a, b]
end
class C < B
  def foo(a, b: 2) = super
end
C.new.foo(1, b: "s")

## assert
class B
  def foo: (Integer, ?b: Integer | String) -> [Integer, Integer | String]
end
class C < B
  def foo: (Integer, ?b: Integer | String) -> [Integer, Integer | String]
end

## update
class B
  def foo(b: 1, **r) = [b, r]
end
class C < B
  def foo(b: 1, **r) = super
end
C.new.foo(b: "s", z: 3)

## assert
class B
  def foo: (?b: Integer | String, **Integer) -> [Integer | String, { z: Integer }]
end
class C < B
  def foo: (?b: Integer | String, **Integer) -> [Integer | String, { z: Integer }]
end
