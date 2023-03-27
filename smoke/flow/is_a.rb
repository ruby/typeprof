# update
def test(x)
  if x.is_a?(Integer)
    x.foo # 3
  else
    x.bar # 5
  end
end

test(1)
test("str")

# diagnostics
(3,6)-(3,9): undefined method: Integer#foo
(5,6)-(5,9): undefined method: String#bar