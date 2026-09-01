## update
module Foo
  module Util
    include Foo
    def helper = "h"
  end
  extend Util
end

def f = Foo.helper

## assert
module Foo
  module Util
    def helper: -> String
  end
end
class Object
  def f: -> String
end
