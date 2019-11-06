def log(x)
end

[1, "str", :sym].each do |x|
  log(x)
end

log(nil)

__END__
# Classes
class Object
  log : (Integer) -> NilClass
      | (NilClass) -> NilClass
      | (String) -> NilClass
      | (Symbol) -> NilClass
end
