def foo(**kw)
  kw
end

foo(n: 42, s: "str")

__END__
# Classes
class Object
  def foo : (**{:n=>Integer, :s=>String}) -> {:n=>Integer, :s=>String}
end
