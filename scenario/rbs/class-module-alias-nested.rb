## update: test.rbs
module Outer
  module Inner
    def self.greet: () -> String
    CONST: Integer
  end
  module InnerAlias = Inner
end

## update: test.rb
def test1
  Outer::InnerAlias.greet
end

def test2
  Outer::InnerAlias::CONST
end

## assert: test.rb
class Object
  def test1: -> String
  def test2: -> Integer
end

## diagnostics: test.rb
