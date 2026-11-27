## update
module Helpers
  def helper = :ok
end

class Foo
  class << self
    include Helpers

    def bar = helper
  end
end

## assert
module Helpers
  def helper: -> :ok
end
class Foo
  extend Helpers
  def self.bar: -> :ok
end
