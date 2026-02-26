## update: test0.rb
module Foo
  X = 1
end

## update: test1.rb
module Foo
  class Bar
    def get_x
      X
    end
  end
end

## assert: test1.rb
module Foo
  class Bar
    def get_x: -> Integer
  end
end

## update: test0.rb
module Foo
  # X is removed
end

## assert: test1.rb
module Foo
  class Bar
    def get_x: -> untyped
  end
end

## update: test0.rb
module Foo
  X = "hello"
end

## assert: test1.rb
module Foo
  class Bar
    def get_x: -> String
  end
end
