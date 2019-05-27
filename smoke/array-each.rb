def log(x)
end

[1, "str", :sym].each do |x|
  log(x)
end

log(nil)

__END__
Object#log :: (Integer) -> NilClass
Object#log :: (String) -> NilClass
Object#log :: (Symbol) -> NilClass
Object#log :: (NilClass) -> NilClass
