## update: test0.rb
module Helpers
  def shout(s) = s.upcase
end

App.shout("hi")

## update: test1.rb
class App
  extend Helpers
end

## assert: test0.rb
module Helpers
  def shout: (String) -> String
end

## diagnostics: test0.rb

## update: test1.rb
class App
end

## assert: test0.rb
module Helpers
  def shout: (untyped) -> untyped
end

## diagnostics: test0.rb
(5,4)-(5,9): undefined method: singleton(App)#shout
