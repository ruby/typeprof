## update
module M
  extend self

  def hello = "hi"
end

M.hello

## assert
module M
  def hello: -> String
  def self.hello: -> String
end

## update
module Helpers
  def shout(s) = s.upcase
end

module App
  extend Helpers
end

App.shout("hi")

## assert
module Helpers
  def shout: (String) -> String
end
module App
  extend Helpers
end
