def log(x)
end

log([1] + ["str"] + [2] + [:sym])

__END__
# Classes
class Object
  def log : (Array[:sym | Integer | String]) -> nil
end
