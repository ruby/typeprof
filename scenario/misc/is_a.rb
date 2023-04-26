## update: test.rb
class C
  def foo(x)
    x.is_a?(self.class)
  end
end

C.new.foo(1)