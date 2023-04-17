## update: test0.rb
class C
end

class D
  def foo
    C.new
  end
end

## assert: test0.rb
class C
end
class D
  def foo: -> C
end

## update: test1.rb
class D
  class C
  end
end

## assert: test0.rb
class C
end
class D
  def foo: -> D::C
end

## update: test1.rb
class D
end

## assert: test0.rb
class C
end
class D
  def foo: -> C
end