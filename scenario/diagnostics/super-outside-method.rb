## update
define_method(:foo) do |x|
  super
end

## diagnostics
(1,0)-(1,13): undefined method: Object#define_method
(2,2)-(2,7): implicit argument passing of super is not supported here
(2,2)-(2,7): undefined method: Object#define_method
