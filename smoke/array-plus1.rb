def log(x)
end

log([1] + ["str"] + [2] + [:sym])

__END__
# Classes
class Object
  log : (Array[:sym | Integer | String]) -> NilClass
end