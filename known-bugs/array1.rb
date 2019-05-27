def bar(x)
end

def test_yield
  yield
end

def foo
  a = [1]
  test_yield do
    bar(a)
  end
  a
end

foo
