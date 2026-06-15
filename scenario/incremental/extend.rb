## update
module Helpers
  def shout(s) = s.upcase
end

class App
end

App.shout("hi")

## assert
module Helpers
  def shout: (untyped) -> untyped
end
class App
end

## diagnostics
(8,4)-(8,9): undefined method: singleton(App)#shout

## update
module Helpers
  def shout(s) = s.upcase
end

class App
  extend Helpers
end

App.shout("hi")

## assert
module Helpers
  def shout: (String) -> String
end
class App
  extend Helpers
end

## diagnostics
