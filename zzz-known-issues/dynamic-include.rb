## update
class Foo
  x = Module.new
  include x # should be warned
  include *[x] # should be warned
end

## diagnostics
should be warned
