## update: test.rb
x = { 1 => 2 }
x.map do |k, v|
#  ^[A]
end

# TODO: support showing type parameters

## hover: [A]
Hash[Integer, Integer]#map : -> Array[...] | -> Enumerator[...]
