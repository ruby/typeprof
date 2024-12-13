## update: test.rb
def check(a)
  case a
  in [Integer => n, String => s]
    [n, s]
  end
end

check([42, "foo"])
