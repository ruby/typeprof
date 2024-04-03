## update: test.rbs
module M
  def foo: -> Integer
end

## update: test.rb
module M
  def foo
    "string"
  end
end

## diagnostics
(3,4)-(3,12): expected: Integer; actual: String
