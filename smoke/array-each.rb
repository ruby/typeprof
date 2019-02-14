def log(x)
end

[1, "str", :sym].each do |x|
  log(x)
end

log(nil)

__END__
Object#log :: (NilClass) -> NilClass
Object#log :: (Symbol) -> NilClass
Object#log :: (String) -> NilClass
Object#log :: (Integer) -> NilClass
