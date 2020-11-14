def foo
  h = { a: 42 }
  h0 = h.merge!({ b: "str" })
  return h0, h
end

__END__
# Classes
class Object
  def foo : -> ([{b: Integer | String, a: Integer | String}, {a: Integer}])
end
