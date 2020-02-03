def log(x)
end

[].each do |x|
  # Currently, x is bot. But, [].each is rarely useful.
  # It would be a good guess to assume a empty receiver of Array#each means a wrong guess.
  # So, it would be good to assume x as any
  log(x)
end

__END__
# Classes
class Object
  log : (bot) -> NilClass
end
