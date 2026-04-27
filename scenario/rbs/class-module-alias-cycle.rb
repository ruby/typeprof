## update: test.rbs
module A = B
module B = A

## update: test.rb
def test
  A
end

## diagnostics: test.rb
