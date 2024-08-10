## update
class Foo
  include Enumerable

  def foo
    ary = []
    ary.each do |ary|
      add ary
    end
  end
end

## assert
class Foo
  include Enumerable
  def foo: -> Array[untyped]
end

## diagnostics
(7,6)-(7,9): undefined method: Foo#add
