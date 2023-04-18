## update
class Foo
  def foo(n)
    1
  end
end

## code_lens
(2,2): (untyped) -> Integer

## update
class Foo
    # a line added and indentation changed
    def foo(n)
        1
    end
end

## code_lens
(3,4): (untyped) -> Integer