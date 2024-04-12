## update: test0.rb
module M
  def foo(n)
  end
end

C.new.foo(1)

## update: test1.rb
class C
  include M
end

## assert: test0.rb
module M
  def foo: (Integer) -> nil
end

## update: test1.rb
class C
end

## assert: test0.rb
module M
  def foo: (untyped) -> nil
end
