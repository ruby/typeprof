def foo
  Hash.new { |h, k| h[k] = [] }
end

foo
__END__
# Classes
class Object
  foo : () -> Hash
end
