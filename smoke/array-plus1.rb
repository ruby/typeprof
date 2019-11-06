def log(x)
end

log([1] + ["str"] + [2] + [:sym])

__END__
# Classes
class Object
  log : (Array[Integer | String | Symbol]) -> NilClass
end
