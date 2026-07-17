## update: test.rbs
module Helpers
  def shout: (String) -> String
end

class App
  extend Helpers
end

class Object
  def takes_mod: (Helpers) -> String
end

## update: test.rb
def check
  takes_mod(App)
end

## assert: test.rb
class Object
  def check: -> String
end

## diagnostics: test.rb
