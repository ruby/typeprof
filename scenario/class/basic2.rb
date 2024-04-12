## update
class C
  class D
    def foo(n)
      C
    end
  end
end

C::D.new(1).foo("str")

## assert
class C
  class C::D
    def foo: (String) -> singleton(C)
  end
end
