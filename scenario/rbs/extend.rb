## update: test.rbs
module Helpers
  def shout: (String) -> String
end
class App
  extend Helpers
end

## update: test.rb
def check
  App.shout("hi")
end

## assert: test.rb
class Object
  def check: -> String
end

## diagnostics: test.rb
