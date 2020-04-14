def log(x)
end

[1, "str", :sym].each do |x|
  log(x)
end

log(nil)

__END__
# Classes
class Object
  def log : (:sym | Integer | NilClass | String) -> NilClass
end
